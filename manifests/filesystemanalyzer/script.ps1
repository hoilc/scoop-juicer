$url = 'https://dmitrybrant.com/files/FileSystemAnalyzer.zip'
$exePath = 'FileSystemAnalyzer.exe'

$archiverName = Split-Path -Path $url -Leaf
$exeName = Split-Path -Path $exePath -Leaf

$TempFolder = New-TempFolder
$TempArchiver = Join-Path $TempFolder $archiverName
$TempExe = Join-Path $TempFolder $exePath

Invoke-WebRequest -Uri $url -OutFile $TempArchiver
Expand-7zArchive -Path $TempArchiver -DestinationPath $TempFolder -Include $exePath

$State.version = Read-ProductVersionFromExe -FilePath $TempExe
$State.compareMode = 'semver'

Remove-Item -Path $TempFolder -Recurse -Force
