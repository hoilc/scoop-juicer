$url = 'https://tos-tools.tos-cn-beijing.volces.com/windows/tosutil#/tosutil.exe'

$State.version = Extract-VersionFromRemoteFileExec $url -Argument 'version' -Regex 'version: v([\d.]+)'

