$ErrorActionPreference = 'Continue'
Set-Location -Path 'C:\Users\Administrator\AviQuest-\dogquest'
$log = 'scripts\verify_refactor.log'

"=== verify_refactor.ps1 start ===" | Out-File -FilePath $log -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== STEP 1: dart format --set-exit-if-changed --output none . ===" | Out-File -FilePath $log -Append -Encoding utf8
& dart format --set-exit-if-changed --output none . 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
$formatExit = $LASTEXITCODE
"FORMAT_EXIT=$formatExit" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== STEP 2: flutter analyze ===" | Out-File -FilePath $log -Append -Encoding utf8
& flutter analyze 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
$analyzeExit = $LASTEXITCODE
"ANALYZE_EXIT=$analyzeExit" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== STEP 3: flutter test ===" | Out-File -FilePath $log -Append -Encoding utf8
& flutter test 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
$testExit = $LASTEXITCODE
"TEST_EXIT=$testExit" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== SUMMARY ===" | Out-File -FilePath $log -Append -Encoding utf8
"FORMAT_EXIT=$formatExit (0=pass)" | Out-File -FilePath $log -Append -Encoding utf8
"ANALYZE_EXIT=$analyzeExit (0=pass)" | Out-File -FilePath $log -Append -Encoding utf8
"TEST_EXIT=$testExit (0=pass)" | Out-File -FilePath $log -Append -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8
"=== verify_refactor.ps1 end ===" | Out-File -FilePath $log -Append -Encoding utf8
