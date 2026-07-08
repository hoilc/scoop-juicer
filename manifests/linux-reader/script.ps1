$url = 'https://eu.diskinternals.com/download/Linux_Reader.exe'

$info = Extract-VersionInfoFromRemotePeFile $url -PreferVersionField "ProductVersion"
Merge-State $info
