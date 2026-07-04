$url = 'https://s3proxy-alp.cdn-zlib.sk/swfs_second_public_files/soft/desktop/Z-Library-latest.exe'

$info = Extract-VersionInfoFromRemotePeFile $url -PreferVersionField "ProductVersion"
Merge-State $info
