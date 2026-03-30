$url = 'https://tunnelmole.com/downloads/tmole.exe'

$State.version = Extract-VersionFromRemoteFileExec $url -Argument '--version' -Regex '(\d\.[\d.]+)'
