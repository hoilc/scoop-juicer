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
        return $matches[1].Trim()
    } else {
        throw "Cannot find version matching '$Regex' in command output"
    }
}

function Extract-VersionInfoFromRemoteFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$ExtractFilePath,
        [ValidateSet("FileVersion", "ProductVersion")]
        [string]$PreferVersionField = "FileVersion"
    )

    $filePath = Get-RemoteFile -Url $Url -ExtractFilePath $ExtractFilePath
    $info = Read-VersionInfoFromExe -FilePath $filePath

    $strippedInfo = @{ version = $null }
    if ($info.FileVersion) {
        $strippedInfo.fileVersion = $info.FileVersion.Trim()
    }
    if ($info.ProductVersion) {
        $strippedInfo.productVersion = $info.ProductVersion.Trim()
    }

    $strippedInfo.version = if ($PreferVersionField -eq 'ProductVersion') {
        if ($info.ProductVersion) { $info.ProductVersion } else { $info.FileVersion }
    } else {
        if ($info.FileVersion) { $info.FileVersion } else { $info.ProductVersion }
    }

    if (-not $strippedInfo.version) {
        throw "Cannot extract version from '$filePath'"
    } else {
        $strippedInfo.version = $strippedInfo.version.Trim()
    }

    return $strippedInfo
}

function Extract-VersionInfoFromRemotePeFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [ValidateSet("FileVersion", "ProductVersion")]
        [string]$PreferVersionField = "FileVersion"
    )

    $info = Get-RemotePeVersion -Url $Url

    $strippedInfo = @{ version = $null }
    if ($info.FileVersion) {
        $strippedInfo.fileVersion = $info.FileVersion.Trim()
    }
    if ($info.ProductVersion) {
        $strippedInfo.productVersion = $info.ProductVersion.Trim()
    }

    $strippedInfo.version = if ($PreferVersionField -eq 'ProductVersion') {
        if ($info.ProductVersion) { $info.ProductVersion } else { $info.FileVersion }
    } else {
        if ($info.FileVersion) { $info.FileVersion } else { $info.ProductVersion }
    }

    if (-not $strippedInfo.version) {
        throw "Cannot extract version from '$filePath'"
    } else {
        $strippedInfo.version = $strippedInfo.version.Trim()
    }

    return $strippedInfo
}

function Extract-VersionFromRemoteZipFileList {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Regex
    )

    $files = Get-RemoteZipFileList -Url $Url
    $fileList = $files -join "`n"

    if ($fileList -match $Regex) {
        return $matches[1].Trim()
    } else {
        throw "Cannot find version matching '$Regex' in remote zip file list"
    }
}

function Extract-VersionFromGitHubReleaseFeed {
    param(
        [Parameter(ParameterSetName = 'Url', Mandatory)][string]$Url,
        [Parameter(ParameterSetName = 'Repo', Mandatory)][string]$Repo
    )

    if ($PSCmdlet.ParameterSetName -eq 'Repo') {
        $Url = "https://github.com/$Repo/releases.atom"
    }

    $response = Invoke-WebRequest -Uri $Url
    [xml]$xml = $response.Content
    $entries = $xml.feed.entry
    if (-not $entries) {
        throw "No entries found in release feed"
    }
    $firstEntry = $entries[0]
    $id = $firstEntry.id
    if ($id -match '/[vV]?([^/]+)$') {
        return $matches[1]
    }
    throw "Cannot extract version from feed entry id: $id"
}

function Extract-VersionFromGitHubReleaseApi {
    param(
        [Parameter(Mandatory)][string]$Repo
    )

    $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
    $headers = @{ Accept = 'application/vnd.github+json' }
    $token = $env:GITHUB_TOKEN
    if ($token) { $headers['Authorization'] = "Bearer $token" }

    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    $tagName = $response.tag_name
    if (-not $tagName) {
        throw "No tag_name found in latest release for $Repo"
    }
    if ($tagName -match '^[vV](.+)$') {
        return $matches[1]
    }
    return $tagName
}