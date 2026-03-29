$EOCDSignature = [byte[]]@(0x50, 0x4b, 0x05, 0x06)
$EOCD64Signature = [byte[]]@(0x50, 0x4b, 0x06, 0x06)
$CDSignature = [byte[]]@(0x50, 0x4b, 0x01, 0x02)

function Read-UInt16LE {
    param([byte[]]$Buffer, [int]$Offset)
    return [BitConverter]::ToUInt16($Buffer, $Offset)
}

function Read-UInt32LE {
    param([byte[]]$Buffer, [int]$Offset)
    return [BitConverter]::ToUInt32($Buffer, $Offset)
}

function Read-UInt64LE {
    param([byte[]]$Buffer, [int]$Offset)
    return [BitConverter]::ToUInt64($Buffer, $Offset)
}

function Find-BytePattern {
    param([byte[]]$Buffer, [byte[]]$Pattern, [int]$StartIndex = 0)

    $patternLen = $Pattern.Length
    $limit = $Buffer.Length - $patternLen
    for ($i = $StartIndex; $i -le $limit; $i++) {
        $found = $true
        for ($j = 0; $j -lt $patternLen; $j++) {
            if ($Buffer[$i + $j] -ne $Pattern[$j]) {
                $found = $false
                break
            }
        }
        if ($found) { return $i }
    }
    return -1
}

function Find-BytePatternLast {
    param([byte[]]$Buffer, [byte[]]$Pattern)

    $lastIndex = -1
    $searchStart = 0
    while ($true) {
        $idx = Find-BytePattern -Buffer $Buffer -Pattern $Pattern -StartIndex $searchStart
        if ($idx -eq -1) { break }
        $lastIndex = $idx
        $searchStart = $idx + 1
    }
    return $lastIndex
}

function Get-RemoteZipCentralDirectoryLocation {
    param([byte[]]$EocdBuffer, [long]$FileSize)

    $eocdIdx = Find-BytePatternLast -Buffer $EocdBuffer -Pattern $EOCDSignature
    if ($eocdIdx -eq -1) {
        throw 'EOCD signature not found'
    }

    $diskNum = Read-UInt16LE -Buffer $EocdBuffer -Offset ($eocdIdx + 4)
    $cdDiskNum = Read-UInt16LE -Buffer $EocdBuffer -Offset ($eocdIdx + 6)
    $diskCDRs = Read-UInt16LE -Buffer $EocdBuffer -Offset ($eocdIdx + 8)
    $totalCDRs = Read-UInt16LE -Buffer $EocdBuffer -Offset ($eocdIdx + 10)
    $cdSize = Read-UInt32LE -Buffer $EocdBuffer -Offset ($eocdIdx + 12)
    $cdOffset = Read-UInt32LE -Buffer $EocdBuffer -Offset ($eocdIdx + 16)

    if ($diskNum -eq 0xffff -or $cdDiskNum -eq 0xffff -or $diskCDRs -eq 0xffff -or
        $totalCDRs -eq 0xffff -or $cdOffset -eq 0xffffffff -or $cdSize -eq 0xffffffff) {
        $eocd64Idx = Find-BytePatternLast -Buffer $EocdBuffer -Pattern $EOCD64Signature
        if ($eocd64Idx -eq -1) {
            throw 'EOCD64 signature not found'
        }
        $cdSize = Read-UInt64LE -Buffer $EocdBuffer -Offset ($eocd64Idx + 40)
        $cdOffset = Read-UInt64LE -Buffer $EocdBuffer -Offset ($eocd64Idx + 48)
    }

    return @{ Offset = $cdOffset; Size = $cdSize }
}

function Get-RemoteZipFileList {
    param(
        [Parameter(Mandatory)][string]$Url
    )

    $response = Invoke-WebRequest -Uri $Url -Method Head
    $fileSize = [long]([string]$response.Headers['Content-Length'])

    $prefetchSize = [Math]::Min(65536, $fileSize)
    $tailStart = $fileSize - $prefetchSize

    $eocdResponse = Invoke-WebRequest -Uri $Url -Headers @{ Range = "bytes=$tailStart-$($fileSize - 1)" }
    $eocdBuffer = $eocdResponse.RawContentStream.ToArray()

    $cdLoc = Get-RemoteZipCentralDirectoryLocation -EocdBuffer $eocdBuffer -FileSize $fileSize

    $cdEnd = $cdLoc.Offset + $cdLoc.Size - 1
    $cdResponse = Invoke-WebRequest -Uri $Url -Headers @{ Range = "bytes=$($cdLoc.Offset)-$cdEnd" }
    $cdBuffer = $cdResponse.RawContentStream.ToArray()

    $files = [System.Collections.Generic.List[string]]::new()
    $pos = 0

    while ($pos -lt $cdBuffer.Length - 4) {
        $sig = @($cdBuffer[$pos], $cdBuffer[$pos + 1], $cdBuffer[$pos + 2], $cdBuffer[$pos + 3])
        if ($sig[0] -ne $CDSignature[0] -or $sig[1] -ne $CDSignature[1] -or
            $sig[2] -ne $CDSignature[2] -or $sig[3] -ne $CDSignature[3]) {
            break
        }

        $fileNameLen = Read-UInt16LE -Buffer $cdBuffer -Offset ($pos + 28)
        $extraFieldLen = Read-UInt16LE -Buffer $cdBuffer -Offset ($pos + 30)
        $fileCommentLen = Read-UInt16LE -Buffer $cdBuffer -Offset ($pos + 32)

        $fileNameBytes = New-Object byte[] $fileNameLen
        [Array]::Copy($cdBuffer, $pos + 46, $fileNameBytes, 0, $fileNameLen)
        $fileName = [System.Text.Encoding]::UTF8.GetString($fileNameBytes)

        $files.Add($fileName)

        $pos += 46 + $fileNameLen + $extraFieldLen + $fileCommentLen
    }

    return $files
}
