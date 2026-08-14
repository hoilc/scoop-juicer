$url = 'https://static.eudic.net/pkg/update_en_win32_full.exe?ts={0}' -f [System.DateTimeOffset]::new( (Get-Date) ).ToUnixTimeSeconds()

$info = Extract-VersionInfoFromRemotePeFile $url -PreferVersionField "ProductVersion"
Merge-State $info
