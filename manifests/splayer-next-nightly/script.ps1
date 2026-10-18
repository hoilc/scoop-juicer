$info = Extract-VersionFromGitHubActions -Repo 'SPlayer-Dev/SPlayer-Next' -Workflow 'dev.yml' -Branch 'dev'
Merge-State $info
