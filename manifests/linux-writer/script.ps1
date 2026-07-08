$url = 'https://eu.diskinternals.com/download/Linux_Writer.exe'

$info = Extract-VersionInfoFromRemotePeFile $url -PreferVersionField "ProductVersion"
Merge-State $info
