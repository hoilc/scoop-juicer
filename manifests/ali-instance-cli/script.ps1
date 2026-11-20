$url = 'https://aliyun-client-assist.oss-accelerate.aliyuncs.com/session-manager/windows/ali-instance-cli.exe'

$State.version = Extract-VersionFromRemoteFileExec $url -Argument '--help' -Regex 'Version ([\d.]+)'
