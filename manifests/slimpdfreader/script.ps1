$url = 'https://cdn.investintech.com/download/InstallSlimPDFReader.exe'

$State.version = Extract-VersionFromRemoteFileVersion $url
$State.compareMode = 'semver'

