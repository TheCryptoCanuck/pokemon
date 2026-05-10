$ErrorActionPreference = 'Continue'
Set-Location -Path 'C:\Users\Administrator\AviQuest-\dogquest'
$log = 'scripts\verify_crashlytics.log'

"=== verify_crashlytics start ===" | Out-File -FilePath $log -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== STEP 1: flutter pub get ===" | Out-File -FilePath $log -Append -Encoding utf8
& flutter pub get 2>&1 | Select-Object -Last 30 | Out-File -FilePath $log -Append -Encoding utf8
$pubExit = $LASTEXITCODE
"PUB_EXIT=$pubExit" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== STEP 2: dart format apply ===" | Out-File -FilePath $log -Append -Encoding utf8
& dart format --summary none . 2>&1 | Select-Object -Last 5 | Out-File -FilePath $log -Append -Encoding utf8
$formatExit = $LASTEXITCODE
"FORMAT_EXIT=$formatExit" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== STEP 3: flutter analyze ===" | Out-File -FilePath $log -Append -Encoding utf8
& flutter analyze 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
$analyzeExit = $LASTEXITCODE
"ANALYZE_EXIT=$analyzeExit" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== SUMMARY ===" | Out-File -FilePath $log -Append -Encoding utf8
"PUB_EXIT=$pubExit" | Out-File -FilePath $log -Append -Encoding utf8
"FORMAT_EXIT=$formatExit" | Out-File -FilePath $log -Append -Encoding utf8
"ANALYZE_EXIT=$analyzeExit" | Out-File -FilePath $log -Append -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8
"=== verify_crashlytics end ===" | Out-File -FilePath $log -Append -Encoding utf8
