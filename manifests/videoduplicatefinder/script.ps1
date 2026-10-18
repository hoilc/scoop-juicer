$info = Extract-VersionFromGitHubActions -Repo '0x90d/videoduplicatefinder' -Workflow 'releases.yml' -Branch 'master' -Format '3.0-{runNumber}-{shortsha}'
Merge-State $info
