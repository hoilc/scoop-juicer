$url = 'http://static.ltr-data.se/files/win64/strarc64.zip'

$info = Extract-VersionInfoFromRemoteFile $url -ExtractFilePath 'strarc.exe'
Merge-State $info

$State.compareMode = $null
