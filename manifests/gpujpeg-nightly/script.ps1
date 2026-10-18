$info = Extract-VersionFromGitHubActions -Repo 'CESNET/GPUJPEG' -Workflow 'ccpp.yml' -Branch 'master'
Merge-State $info
