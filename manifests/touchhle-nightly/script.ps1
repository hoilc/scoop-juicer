$info = Extract-VersionFromGitHubActions -Repo 'touchHLE/touchHLE' -Workflow 'touchHLE_release.yml' -Branch 'trunk'
Merge-State $info
