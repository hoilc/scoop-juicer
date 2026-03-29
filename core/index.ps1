#Requires -Version 7.4
<#
.SYNOPSIS
  Scoop-Juicer version checker runner.
.PARAMETER Name
  Names of manifests to run. Leave blank to run all.
.PARAMETER Path
  Path to the folder containing manifest directories.
.EXAMPLE
  .\core\index.ps1
  Run all manifests in ./manifests/
.EXAMPLE
  .\core\index.ps1 -Name 'ExampleApp'
  Run only the ExampleApp manifest
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string[]]$Name,
    [Parameter(Position = 1)][string]$Path = (Join-Path $PWD 'manifests')
)

Set-StrictMode -Version 3.0

. (Join-Path $PSScriptRoot 'utils.ps1')
. (Join-Path $PSScriptRoot 'helpers.ps1')

if (-not (Test-Path -Path $Path)) {
    throw "Manifest directory '${Path}' does not exist."
}

if ($Name) {
    $manifestDirs = $Name | ForEach-Object {
        $dir = Join-Path $Path $_
        if (Test-Path -Path $dir) { Get-Item $dir } else { Write-Log "'${_}' not found, skipping" -Level Warning }
    } | Where-Object { $_ }
} else {
    $manifestDirs = Get-ChildItem -Path $Path -Directory
}

$total = ($manifestDirs | Measure-Object).Count
Write-Log "Found ${total} manifest(s)"

$hasChanges = $false
$current = 0
foreach ($dir in $manifestDirs) {
    $current++
    $manifestName = $dir.Name
    $scriptPath = Join-Path $dir.FullName 'script.ps1'
    $statePath = Join-Path $dir.FullName 'state.json'

    Write-Log "[$current/$total] Checking ${manifestName}..."

    if (-not (Test-Path -Path $scriptPath)) {
        Write-Log "script.ps1 not found in ${manifestName}, skipping" -Level Warning -Prefix $manifestName
        continue
    }

    $PreviousState = @{ version = $null }
    if (Test-Path -Path $statePath) {
        try {
            $PreviousState = Get-Content -Path $statePath -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            Write-Log "Failed to read state.json: $_" -Level Warning -Prefix $manifestName
        }
    }

    $State = @{
        version      = $null
        compareMode  = $null
    }

    try {
        & $scriptPath
    } catch {
        Write-Log "Error: $_" -Level Error -Prefix $manifestName
        continue
    }

    if (-not $State.version) {
        Write-Log "No version detected" -Level Warning -Prefix $manifestName
        continue
    }

    $oldVersion = if ($PreviousState.Contains('version')) { $PreviousState.version } else { $null }
    $newVersion = $State.version

    $compareMode = if ($State.Contains('compareMode')) { $State.compareMode } else { $null }

    $StateExcludeKeys = @('compareMode')
    $saveData = @{}
    foreach ($key in $State.Keys) {
        if ($key -notin $StateExcludeKeys) { $saveData[$key] = $State[$key] }
    }

    $result = Compare-Version -OldVersion $oldVersion -NewVersion $newVersion -CompareMode $compareMode

    switch ($result) {
        'new' {
            $saveData | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
            Write-Log "${newVersion} (new)" -Prefix $manifestName
            Save-GitChange -Path $statePath -ManifestName $manifestName -Version $newVersion
            $hasChanges = $true
        }
        'updated' {
            $saveData | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
            Write-Log "${oldVersion} -> ${newVersion} (updated)" -Prefix $manifestName
            Save-GitChange -Path $statePath -ManifestName $manifestName -Version $newVersion -OldVersion $oldVersion
            $hasChanges = $true
        }
        'rollback' {
            Write-Log "${oldVersion} -> ${newVersion} (rollback, skipped)" -Level Warning -Prefix $manifestName
        }
        default {
            Write-Log "${newVersion} (unchanged)" -Prefix $manifestName
        }
    }
}

if ((Test-Path -Path Env:\CI) -and $hasChanges) {
    Write-Log 'Pushing changes...'
    git push
}

Write-Log 'Done'

Remove-TempBase
