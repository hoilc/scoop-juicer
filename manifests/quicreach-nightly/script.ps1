$info = Extract-VersionFromGitHubActions -Repo 'microsoft/quicreach' -Workflow 'build.yml' -Branch 'main'
Merge-State $info
