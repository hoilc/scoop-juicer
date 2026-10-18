$info = Extract-VersionFromGitHubActions -Repo 'ggml-org/whisper.cpp' -Workflow 'build-windows.yml' -Branch 'master'
Merge-State $info
