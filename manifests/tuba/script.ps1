$info = Extract-VersionFromGitHubActions -Repo 'GeopJr/Tuba' -Workflow 'msys2.yml' -Branch 'main'
Merge-State $info
