$url = 'https://obs-community.obs.cn-north-1.myhuaweicloud.com/obsutil/current/obsutil_windows_amd64.zip'
$versionRegex = 'obsutil_windows_amd64_([\d.]+)'

$archiverName = Split-Path -Path $url -Leaf

$TempFolder = New-TempFolder
$TempArchiver = Join-Path $TempFolder $archiverName

Invoke-WebRequest -Uri $url -OutFile $TempArchiver
$filelist = Get-7zArchiveList $TempArchiver

if ($filelist -match $versionRegex) {
    $State.version = $matches[1]
} else {
    throw "cannot find version in file list"
}

$State.compareMode = 'semver'

Remove-Item -Path $TempFolder -Recurse -Force
