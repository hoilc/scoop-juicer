$url = 'https://obs-community.obs.cn-north-1.myhuaweicloud.com/obsutil/current/obsutil_windows_amd64.zip'

$tempFile = Get-RemoteFile $url
$filelist = Get-7zArchiveList $tempFile

if ($filelist -match 'obsutil_windows_amd64_([\d.]+)') {
    $State.version = $matches[1]
} else {
    throw "cannot find version in file list"
}

$State.compareMode = 'semver'
