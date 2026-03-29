$url = 'https://public.dhe.ibm.com/software/websphere/appserv/support/tools/iema/com.ibm.java.diagnostics.memory.analyzer.MemoryAnalyzer.semeru-win32.win32.x86_64.zip'

$State.version = Extract-VersionFromRemoteZipFileList $url -Regex 'com.ibm.dtfj.feature_([\d.]+)'

$State.compareMode = 'semver'
