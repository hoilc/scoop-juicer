$url = 'https://cdn.ipip.net/17mon/besttrace.exe'

$info = Extract-VersionInfoFromRemoteFile $url
Merge-State $info

$State.compareMode = 'semver'
