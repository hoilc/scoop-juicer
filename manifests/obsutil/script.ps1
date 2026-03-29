$url = 'https://obs-community.obs.cn-north-1.myhuaweicloud.com/obsutil/current/obsutil_windows_amd64.zip'

$State.version = Extract-VersionFromRemoteZipFileList $url -Regex 'obsutil_windows_amd64_([\d.]+)'

$State.compareMode = 'semver'
