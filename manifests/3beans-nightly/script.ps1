$info = Extract-VersionFromGitHubActions -Repo 'Hydr8gon/3Beans' -Workflow 'autobuild.yml' -Branch 'main'
Merge-State $info
