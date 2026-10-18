$info = Extract-VersionFromGitHubActions -Repo 'Notsfsssf/pixez-flutter' -Workflow 'build_windows.yml' -Branch 'master'
Merge-State $info
