$url = 'https://www.digicert.com/StaticFiles/DigiCertUtil.zip'

$info = Extract-VersionInfoFromRemoteFile $url -ExtractFilePath 'DigiCertUtil.exe'
Merge-State $info
