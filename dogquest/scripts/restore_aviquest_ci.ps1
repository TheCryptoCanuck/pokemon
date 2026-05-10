$ErrorActionPreference = 'Stop'
Set-Location -Path 'C:\Users\Administrator\AviQuest-'
$log = 'dogquest\scripts\restore_aviquest_ci.log'

"=== restore_aviquest_ci start ===" | Out-File -FilePath $log -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8

# Pull the previous AviQuest CI yaml content from git history
"--- pulling HEAD~1:.github/workflows/ci.yml ---" | Out-File -FilePath $log -Append -Encoding utf8
$aviquestCi = git show 'HEAD~1:.github/workflows/ci.yml'
$aviquestCi | Out-File -FilePath '.github\workflows\aviquest-ci.yml' -Encoding utf8
"--- wrote aviquest-ci.yml ($($aviquestCi.Length) chars) ---" | Out-File -FilePath $log -Append -Encoding utf8

# Rename current ci.yml to dogquest-ci.yml so file names are unambiguous
"--- renaming ci.yml -> dogquest-ci.yml ---" | Out-File -FilePath $log -Append -Encoding utf8
git mv '.github/workflows/ci.yml' '.github/workflows/dogquest-ci.yml' 2>&1 | Out-File -FilePath $log -Append -Encoding utf8

# Stage + commit both
"--- git add + commit ---" | Out-File -FilePath $log -Append -Encoding utf8
git add '.github/workflows/aviquest-ci.yml' '.github/workflows/dogquest-ci.yml' 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
git commit -m "OPS-001: split CI workflows by project (aviquest-ci.yml restored from history, dogquest-ci.yml renamed for clarity)" 2>&1 | Out-File -FilePath $log -Append -Encoding utf8

"--- final log ---" | Out-File -FilePath $log -Append -Encoding utf8
git log --oneline -n 4 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
"=== restore_aviquest_ci end ===" | Out-File -FilePath $log -Append -Encoding utf8
