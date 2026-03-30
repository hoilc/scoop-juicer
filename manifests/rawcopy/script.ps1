$url = 'http://static.ltr-data.se/files/win64/rawcopy64.zip'

$info = Extract-VersionInfoFromRemoteFile $url -ExtractFilePath 'rawcopy.exe'
Merge-State $info

$State.compareMode = 'semver'
