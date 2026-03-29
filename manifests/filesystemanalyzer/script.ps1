$url = 'https://dmitrybrant.com/files/FileSystemAnalyzer.zip'

$State.version = Extract-VersionFromRemoteFileProductVersion $url -ExtractFilePath 'FileSystemAnalyzer.exe'
$State.compareMode = 'semver'
