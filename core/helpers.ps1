function Get-RemoteFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$ExtractFilePath
    )

    if ($Url -match '#/(?<filename>[^#]+)$') {
        $fileName = $matches['filename']
        $downloadUrl = $Url -replace '#/[^#]+$', ''
    } else {
        $downloadUrl = $Url
        $uri = [System.Uri]$Url
        $fileName = Split-Path -Path $uri.AbsolutePath -Leaf
    }

    $tempFolder = New-TempFolder
    $tempFile = Join-Path $tempFolder $fileName

    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile

    if ($ExtractFilePath) {
        Expand-7zArchive -Path $tempFile -DestinationPath $tempFolder -Include $ExtractFilePath
        return Join-Path $tempFolder $ExtractFilePath
    }

    return $tempFile
}

function Extract-VersionFromRemoteFileExec {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$ExtractFilePath,
        [string]$Argument,
        [Parameter(Mandatory)][string]$Regex
    )

    $filePath = Get-RemoteFile -Url $Url -ExtractFilePath $ExtractFilePath

    $output = (& $filePath $Argument 2>&1) -join "`n"

    if ($output -match $Regex) {
        return $matches[1]
    } else {
        throw "Cannot find version matching '$Regex' in command output"
    }
}

function Extract-VersionFromRemoteFileVersion {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$ExtractFilePath
    )

    $filePath = Get-RemoteFile -Url $Url -ExtractFilePath $ExtractFilePath

    return Read-FileVersionFromExe -FilePath $filePath
}

function Extract-VersionFromRemoteFileProductVersion {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$ExtractFilePath
    )

    $filePath = Get-RemoteFile -Url $Url -ExtractFilePath $ExtractFilePath

    return Read-ProductVersionFromExe -FilePath $filePath
}