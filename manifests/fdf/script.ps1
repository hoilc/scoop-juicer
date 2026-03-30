$url = 'http://static.ltr-data.se/files/win64/fdf64.zip'

$info = Extract-VersionInfoFromRemoteFile $url -ExtractFilePath 'fdf.exe'
Merge-State $info

# $State.version = Extract-VersionFromRemoteFileExec $url -ExtractFilePath 'fdf.exe' -Argument '--help' -Regex 'Version ([\d.]+?)\.?\s' -PreferVersionField "ProductVersion"
$State.compareMode = 'semver'
