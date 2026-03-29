#Requires -Version 7.4

$ErrorActionPreference = 'Stop'
if (Test-Path -Path Env:\CI) { $ProgressPreference = 'SilentlyContinue' }

$script:DefaultUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36'

$PSDefaultParameterValues["invoke-webrequest:UserAgent"] = $script:DefaultUserAgent
$PSDefaultParameterValues["invoke-restmethod:UserAgent"] = $script:DefaultUserAgent

$PSDefaultParameterValues["invoke-webrequest:TimeoutSec"] = 10
$PSDefaultParameterValues["invoke-restmethod:TimeoutSec"] = 10

$PSDefaultParameterValues["invoke-webrequest:proxy"] = $env:http_proxy
$PSDefaultParameterValues["invoke-restmethod:proxy"] = $env:http_proxy

function Write-Log {
    param(
        [Parameter(Position = 0, Mandatory)][string]$Message,
        [string]$Prefix,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $color = switch ($Level) {
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        default   { 'Cyan' }
    }

    $ts = Get-Date -Format 'HH:mm:ss'
    $label = $Prefix ? "[$Prefix] " : ''
    Write-Host -ForegroundColor $color "$ts $label$Message"
}

function Invoke-GitHubApi {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers = @{}
    )

    $token = $env:GITHUB_TOKEN
    if ($token) { $Headers['Authorization'] = "Bearer $token" }
    $Headers['Accept'] = 'application/vnd.github+json'

    return Invoke-RestMethod -Uri $Uri -Headers $Headers
}

function Get-RedirectedUrl {
    param([Parameter(Mandatory)][string]$Url)
    $response = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 0 -ErrorAction Ignore -SkipHttpErrorCheck
    if ($response.StatusCode -ge 300 -and $response.StatusCode -lt 400) {
        return $response.Headers.Location
    } else {
        throw "Expected redirect but got $($response.StatusCode) from $Url"
    }
}

function Read-FileVersionFromExe {
    param([Parameter(Mandatory)][string]$FilePath)
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
    return $versionInfo.FileVersion
}

function Read-ProductVersionFromExe {
    param([Parameter(Mandatory)][string]$FilePath)
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
    return $versionInfo.ProductVersion
}

$global:JuicerTempBase = Join-Path ([System.IO.Path]::GetTempPath()) "scoop-juicer-$(Get-Random)"
New-Item -Path $global:JuicerTempBase -ItemType Directory -Force | Out-Null

function New-TempFile {
    return Join-Path $global:JuicerTempBase "tmp-$(Get-Random)"
}

function New-TempFolder {
    $tempPath = Join-Path $global:JuicerTempBase "tmp-$(Get-Random)"
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    return $tempPath
}

function Remove-TempBase {
    if (Test-Path $global:JuicerTempBase) {
        Remove-Item -Path $global:JuicerTempBase -Recurse -Force
    }
}

function Compare-Version {
    param(
        [string]$OldVersion,
        [Parameter(Mandatory)][string]$NewVersion,
        [string]$CompareMode
    )

    if (-not $OldVersion) { return 'new' }
    if ($OldVersion -eq $NewVersion) { return 'unchanged' }

    switch ($CompareMode) {
        'semver' {
            $parseSemver = {
                param([string]$v)
                if ($v -match '^v?(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\.(?<build>\d+))?') {
                    return [version]::new(
                        [int]$matches['major'],
                        $(if ($matches['minor']) { [int]$matches['minor'] } else { 0 }),
                        $(if ($matches['patch']) { [int]$matches['patch'] } else { 0 }),
                        $(if ($matches['build']) { [int]$matches['build'] } else { 0 })
                    )
                }
                return $null
            }
            $old = & $parseSemver $OldVersion
            $new = & $parseSemver $NewVersion
            if ($null -eq $old -or $null -eq $new) {
                return 'updated'
            }
            if ($new -gt $old) { return 'updated' }
            if ($new -lt $old) { return 'rollback' }
            return 'unchanged'
        }
        'numeric' {
            $oldNum = 0; $newNum = 0
            [int]::TryParse($OldVersion, [ref]$oldNum) | Out-Null
            [int]::TryParse($NewVersion, [ref]$newNum) | Out-Null
            if ($newNum -gt $oldNum) { return 'updated' }
            if ($newNum -lt $oldNum) { return 'rollback' }
            return 'unchanged'
        }
        default {
            return 'updated'
        }
    }
}

function Save-GitChange {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ManifestName,
        [Parameter(Mandatory)][string]$Version,
        [string]$OldVersion
    )

    if (-not (Test-Path -Path Env:\CI)) { return }

    $runId = $env:GITHUB_RUN_ID
    $suffix = if ($runId) { " [${runId}]" } else { '' }
    $message = if ($OldVersion) {
        "manifest(${ManifestName}): ${OldVersion} -> ${Version}${suffix}"
    } else {
        "manifest(${ManifestName}): init version ${Version}${suffix}"
    }

    git add $Path 2>&1 | Out-Null
    git commit -m $message 2>&1 | Out-Null
}

function Find-7zPath {
    $7z = if (Get-Command '7z' -ErrorAction Ignore) {
        '7z'
    } elseif (Test-Path (Join-Path $env:SCOOP 'shims\7z.exe')) {
        Join-Path $env:SCOOP 'shims\7z.exe'
    } elseif (Test-Path (Join-Path $env:ProgramFiles '7-Zip\7z.exe')) {
        Join-Path $env:ProgramFiles '7-Zip\7z.exe'
    } else {
        throw '7z not found'
    }
    return $7z
}

function Expand-7zArchive {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$DestinationPath,
        [string[]]$Include
    )

    $7z = Find-7zPath

    if (-not $DestinationPath) {
        $DestinationPath = (Get-Item $Path).DirectoryName
    }

    $logFile = Join-Path $DestinationPath '7zip.log'
    $arguments = @('x', $Path, "-o$DestinationPath", '-y', '-aoa')
    if ($Include) {
        $arguments += $Include
    }

    & $7z @arguments 2>&1 | Out-File -FilePath $logFile -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        $log = Get-Content -Path $logFile -Raw
        throw "7z extraction failed (exit code $LASTEXITCODE): $log"
    }
}

function Get-7zArchiveList {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $7z = Find-7zPath

    $output = & $7z l $Path 2>&1 | Out-String
    return $output
}
