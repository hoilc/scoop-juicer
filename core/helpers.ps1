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

function Extract-VersionFromGitHubActions {
    <#
    .SYNOPSIS
      Builds a version string from the latest GitHub Actions workflow run (pull request runs are excluded).
    .PARAMETER Repo
      Repository in 'owner/name' form.
    .PARAMETER Workflow
      Workflow file name (e.g. 'build.yml') or id.
    .PARAMETER Branch
      Only consider runs on this branch.
    .PARAMETER Status
      Run status/conclusion filter, defaults to 'success'. Use 'completed' to accept any
      finished run regardless of conclusion (e.g. when an unrelated failing job marks the
      whole run as failed). Pass '' to disable filtering.
    .PARAMETER Event
      Only consider runs triggered by this event (e.g. 'push', 'schedule', 'workflow_dispatch').
    .PARAMETER Format
      Version template, defaults to 'b{runNumber}-{date}-{shortsha}' (e.g. 'b335-20261011-0c7be69').
      Placeholders: {date}, {time}, {sha}, {shortsha}, {runId}, {runNumber}.
      {date} and {time} accept a custom .NET format, e.g. '{date:yyyy-MM-dd}'.
      Date and time refer to the run creation time in UTC.
    .NOTES
      The returned hashtable includes compareMode 'githubActions', so after Merge-State an
      older workflow run is treated as a rollback and skipped. Set $State.compareMode
      afterwards to override.
    .EXAMPLE
      Extract-VersionFromGitHubActions -Repo 'owner/repo' -Workflow 'build.yml' -Branch 'main'
    #>
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Workflow,
        [string]$Branch,
        [AllowEmptyString()]
        [ValidateSet('', 'completed', 'action_required', 'cancelled', 'failure', 'neutral', 'skipped', 'stale', 'success', 'timed_out', 'in_progress', 'queued', 'requested', 'waiting', 'pending')]
        [string]$Status = 'success',
        [string]$Event,
        [string]$Format = 'b{runNumber}-{date}-{shortsha}',
        [int]$ShortShaLength = 7
    )

    $apiUrl = "https://api.github.com/repos/$Repo/actions/workflows/$Workflow/runs"

    $query = [ordered]@{ per_page = 1; exclude_pull_requests = 'true' }
    if ($Branch) { $query.branch = $Branch }
    if ($Status) { $query.status = $Status }
    if ($Event) { $query.event = $Event }

    $queryString = ($query.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, [uri]::EscapeDataString("$($_.Value)") }) -join '&'
    $response = Invoke-GitHubApi -Uri "${apiUrl}?${queryString}"

    $run = $response.workflow_runs | Select-Object -First 1
    if (-not $run) {
        throw "No matching workflow runs found for '$Repo'"
    }

    $builtAt = [DateTimeOffset]::Parse($run.created_at).UtcDateTime
    $sha = $run.head_sha
    $shortSha = $sha.Substring(0, [Math]::Min($ShortShaLength, $sha.Length))

    $version = [regex]::Replace($Format, '\{(date|time|sha|shortsha|runId|runNumber)(?::([^}]+))?\}', {
        param($m)
        $custom = if ($m.Groups[2].Success) { $m.Groups[2].Value } else { $null }
        switch ($m.Groups[1].Value) {
            'date'      { $builtAt.ToString(($custom ? $custom : 'yyyyMMdd'), [cultureinfo]::InvariantCulture) }
            'time'      { $builtAt.ToString(($custom ? $custom : 'HHmmss'), [cultureinfo]::InvariantCulture) }
            'sha'       { $sha }
            'shortsha'  { $shortSha }
            'runId'     { [string]$run.id }
            'runNumber' { [string]$run.run_number }
        }
    })

    return @{
        version     = $version
        compareMode = 'githubActions'
        commit      = $sha
        runId       = [string]$run.id
        runNumber   = [string]$run.run_number
        builtAt     = $builtAt.ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)
    }
}