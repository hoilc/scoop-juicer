$url = 'https://www.rj-texted.se/downloads/rj-portable.exe'

$info = Extract-VersionInfoFromRemotePeFile $url -PreferVersionField "ProductVersion"
Merge-State $info
