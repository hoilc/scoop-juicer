function Get-RemotePeVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    # 注入 C# 辅助类（只在不存在时加载）
    if (-not ([System.Management.Automation.PSTypeName]'PEReader').Type) {
        Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;

public class PEReader {
    public static int ToInt32(byte[] data, int offset) => (offset + 4 <= data.Length) ? BitConverter.ToInt32(data, offset) : 0;
    public static ushort ToInt16(byte[] data, int offset) => (offset + 2 <= data.Length) ? BitConverter.ToUInt16(data, offset) : (ushort)0;

    public static uint RvaToOffset(uint rva, byte[] headerChunk, int peOffset) {
        if (rva == 0) return 0;
        ushort numSections = ToInt16(headerChunk, peOffset + 6);
        ushort sizeOptionalHeader = ToInt16(headerChunk, peOffset + 20);
        int sectionTableOffset = peOffset + 24 + sizeOptionalHeader;

        for (int i = 0; i < numSections; i++) {
            int currentSection = sectionTableOffset + (i * 40);
            if (currentSection + 40 > headerChunk.Length) break;
            uint virtualSize = (uint)ToInt32(headerChunk, currentSection + 8);
            uint virtualAddress = (uint)ToInt32(headerChunk, currentSection + 12);
            uint pointerToRawData = (uint)ToInt32(headerChunk, currentSection + 20);
            if (rva >= virtualAddress && rva < virtualAddress + virtualSize) return pointerToRawData + (rva - virtualAddress);
        }
        return 0;
    }

    public static uint GetVersionInfoRva(byte[] resChunk) {
        if (resChunk == null || resChunk.Length < 16) return 0;
        ushort namedEntries = ToInt16(resChunk, 12);
        ushort idEntries = ToInt16(resChunk, 14);
        for (int i = 0; i < namedEntries + idEntries; i++) {
            int entryOffset = 16 + (i * 8);
            if (entryOffset + 8 > resChunk.Length) break;
            if ((ToInt32(resChunk, entryOffset) & 0xFFFF) == 16) { // RT_VERSION
                uint level2Offset = (uint)ToInt32(resChunk, entryOffset + 4) & 0x7FFFFFFF;
                if (level2Offset + 20 > resChunk.Length) return 0;
                uint level3Offset = (uint)ToInt32(resChunk, (int)level2Offset + 16 + 4) & 0x7FFFFFFF;
                if (level3Offset + 20 > resChunk.Length) return 0;
                uint dataEntryOffset = (uint)ToInt32(resChunk, (int)level3Offset + 16 + 4);
                if (dataEntryOffset + 8 > resChunk.Length) return 0;
                return (uint)ToInt32(resChunk, (int)dataEntryOffset);
            }
        }
        return 0;
    }

    public static string ExtractUnicodeString(byte[] data, string key) {
        string hexData = BitConverter.ToString(data).Replace("-", "");
        byte[] keyBytes = Encoding.Unicode.GetBytes(key);
        string hexKey = BitConverter.ToString(keyBytes).Replace("-", "");
        int pos = hexData.IndexOf(hexKey);
        if (pos == -1) return null;

        int startIdx = (pos / 2) + keyBytes.Length;
        while (startIdx < data.Length && data[startIdx] == 0) startIdx++;

        List<byte> res = new List<byte>();
        for (int i = startIdx; i < data.Length - 1; i += 2) {
            if (data[i] == 0 && data[i+1] == 0) break;
            res.Add(data[i]); res.Add(data[i+1]);
        }
        return Encoding.Unicode.GetString(res.ToArray()).Trim();
    }
}
'@
    }

    $results = [ordered]@{
        FileVersion         = $null
        ProductVersion      = $null
        FixedFileVersion    = $null
        FixedProductVersion = $null
        Url                 = $Url
    }

    try {
        # 1. 读取 PE Header
        $headerBytes = (Invoke-WebRequest -Uri $Url -Headers @{ Range = "bytes=0-4095" } -Method Get -TimeoutSec 15).Content
        $peOffset = [PEReader]::ToInt32($headerBytes, 0x3C)
        $magic = [PEReader]::ToInt16($headerBytes, $peOffset + 24)
        $dataDirStart = if ($magic -eq 0x20b) { $peOffset + 24 + 112 } else { $peOffset + 24 + 96 }
        $resRva = [PEReader]::ToInt32($headerBytes, $dataDirStart + 16)
        $resFileOffset = [PEReader]::RvaToOffset($resRva, $headerBytes, $peOffset)

        if ($resFileOffset -eq 0) { throw "未在 PE 中找到资源节偏移" }

        # 2. 读取资源目录
        $resBytes = (Invoke-WebRequest -Uri $Url -Headers @{ Range = "bytes=$resFileOffset-$($resFileOffset + 8192)" } -Method Get).Content
        $versionRva = [PEReader]::GetVersionInfoRva($resBytes)
        $versionFileOffset = [PEReader]::RvaToOffset($versionRva, $headerBytes, $peOffset)

        if ($versionFileOffset -eq 0) { throw "未在资源树中找到版本信息" }

        # 3. 读取版本数据块
        $verBytes = (Invoke-WebRequest -Uri $Url -Headers @{ Range = "bytes=$versionFileOffset-$($versionFileOffset + 2048)" } -Method Get).Content

        # 解析 FixedFileInfo (数字版) - 修复了语法错误 [System.BitConverter]
        $hex = [System.BitConverter]::ToString($verBytes).Replace("-", "")
        $sigPos = $hex.IndexOf("BD04EFFE") # 0xFEEF04BD
        if ($sigPos -ge 0) {
            $idx = ($sigPos / 2) + 8
            # VS_FIXEDFILEINFO 结构中: MS 是主/次版本, LS 是修订/生成号
            $results.FixedFileVersion = "{0}.{1}.{2}.{3}" -f [PEReader]::ToInt16($verBytes, $idx+2), [PEReader]::ToInt16($verBytes, $idx), [PEReader]::ToInt16($verBytes, $idx+6), [PEReader]::ToInt16($verBytes, $idx+4)
            $results.FixedProductVersion = "{0}.{1}.{2}.{3}" -f [PEReader]::ToInt16($verBytes, $idx+10), [PEReader]::ToInt16($verBytes, $idx+8), [PEReader]::ToInt16($verBytes, $idx+14), [PEReader]::ToInt16($verBytes, $idx+12)
        }

        # 解析文本版版本号
        $results.FileVersion = [PEReader]::ExtractUnicodeString($verBytes, "FileVersion")
        $results.ProductVersion = [PEReader]::ExtractUnicodeString($verBytes, "ProductVersion")

        return $results
    }
    catch {
        Write-Warning "解析失败: $($_.Exception.Message)"
        return $results
    }
}
