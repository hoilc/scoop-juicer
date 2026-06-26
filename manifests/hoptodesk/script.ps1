$url = 'https://download.hoptodesk.com/HopToDesk64.exe'

$info = Extract-VersionInfoFromRemotePeFile $url -PreferVersionField "ProductVersion"
Merge-State $info
