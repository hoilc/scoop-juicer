$url = 'https://dmitrybrant.com/files/FileSystemAnalyzer.zip'

$info = Extract-VersionInfoFromRemoteFile $url -ExtractFilePath 'FileSystemAnalyzer.exe' -PreferVersionField "ProductVersion"
Merge-State $info
