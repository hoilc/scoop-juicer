$url = 'https://download.mypikpak.net/desktop/official_PikPak.exe'

$info = Extract-VersionInfoFromRemoteFile $url -PreferVersionField "ProductVersion"
Merge-State $info
