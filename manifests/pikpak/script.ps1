$url = 'https://download.mypikpak.net/desktop/official_PikPak.exe'

$info = Extract-VersionInfoFromRemotePeFile $url -PreferVersionField "ProductVersion"
Merge-State $info
