$info = Extract-VersionFromGitHubActions -Repo 'SamboyCoding/Cpp2IL' -Workflow 'dotnet-core.yml' -Branch 'development'
Merge-State $info
