$url = 'https://cdn.investintech.com/download/InstallSlimPDFReader.exe'

$info = Extract-VersionInfoFromRemoteFile $url -PreferVersionField "FileVersion"
Merge-State $info

