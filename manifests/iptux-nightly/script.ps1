$info = Extract-VersionFromGitHubActions -Repo 'iptux-src/iptux' -Workflow 'windows.yml' -Branch 'main'
Merge-State $info
