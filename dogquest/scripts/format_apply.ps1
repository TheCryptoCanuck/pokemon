$ErrorActionPreference = 'Continue'
Set-Location -Path 'C:\Users\Administrator\AviQuest-\dogquest'
$log = 'scripts\format_apply.log'

"=== format_apply.ps1 start ===" | Out-File -FilePath $log -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== dart format . (apply, write to disk) ===" | Out-File -FilePath $log -Append -Encoding utf8
& dart format --summary none . 2>&1 | Select-Object -Last 5 | Out-File -FilePath $log -Append -Encoding utf8
$exit = $LASTEXITCODE
"FORMAT_APPLY_EXIT=$exit" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== verify clean (--set-exit-if-changed) ===" | Out-File -FilePath $log -Append -Encoding utf8
& dart format --output none --set-exit-if-changed . 2>&1 | Select-Object -Last 5 | Out-File -FilePath $log -Append -Encoding utf8
$verifyExit = $LASTEXITCODE
"FORMAT_VERIFY_EXIT=$verifyExit (0=clean)" | Out-File -FilePath $log -Append -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8
"=== format_apply.ps1 end ===" | Out-File -FilePath $log -Append -Encoding utf8
