$url = 'https://cdn.investintech.com/download/InstallSlimPDFReader.exe'

$archiverName = Split-Path -Path $url -Leaf

$TempFolder = New-TempFolder
$TempArchiver = Join-Path $TempFolder $archiverName

Invoke-WebRequest -Uri $url -OutFile $TempArchiver

$State.version = Read-FileVersionFromExe -FilePath $TempArchiver
$State.compareMode = 'semver'

Remove-Item -Path $TempFolder -Recurse -Force
