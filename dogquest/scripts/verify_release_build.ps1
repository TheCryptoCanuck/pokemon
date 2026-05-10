$ErrorActionPreference = 'Continue'
Set-Location -Path 'C:\Users\Administrator\AviQuest-\dogquest'
$log = 'scripts\verify_release_build.log'

"=== verify_release_build start ===" | Out-File -FilePath $log -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== flutter build apk --release ===" | Out-File -FilePath $log -Append -Encoding utf8
& flutter build apk --release 2>&1 | Select-Object -Last 25 | Out-File -FilePath $log -Append -Encoding utf8
$buildExit = $LASTEXITCODE
"BUILD_EXIT=$buildExit" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== verify APK exists + size ===" | Out-File -FilePath $log -Append -Encoding utf8
$apk = 'build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apk) {
    $sz = (Get-Item $apk).Length
    "APK exists at $apk ($sz bytes)" | Out-File -FilePath $log -Append -Encoding utf8
} else {
    "APK NOT FOUND at $apk" | Out-File -FilePath $log -Append -Encoding utf8
}

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== verify signature with apksigner ===" | Out-File -FilePath $log -Append -Encoding utf8
$apksigner = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools\*\apksigner.bat" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
if ($apksigner) {
    "using apksigner at $($apksigner.FullName)" | Out-File -FilePath $log -Append -Encoding utf8
    & $apksigner.FullName verify --print-certs $apk 2>&1 | Select-Object -First 15 | Out-File -FilePath $log -Append -Encoding utf8
} else {
    "apksigner not found in build-tools, skipping signature inspection" | Out-File -FilePath $log -Append -Encoding utf8
}

(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8
"=== verify_release_build end ===" | Out-File -FilePath $log -Append -Encoding utf8
