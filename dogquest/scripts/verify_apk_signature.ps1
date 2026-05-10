$ErrorActionPreference = 'Continue'
Set-Location -Path 'C:\Users\Administrator\AviQuest-\dogquest'
$log = 'scripts\verify_apk_signature.log'

# Set JAVA_HOME from Android Studio's bundled JBR for this process only
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

"=== verify_apk_signature start ===" | Out-File -FilePath $log -Encoding utf8
(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8
"JAVA_HOME=$env:JAVA_HOME" | Out-File -FilePath $log -Append -Encoding utf8

$apk = 'build\app\outputs\flutter-apk\app-release.apk'
$apksigner = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools\*\apksigner.bat" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
"apksigner=$($apksigner.FullName)" | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== apksigner verify --print-certs ===" | Out-File -FilePath $log -Append -Encoding utf8
& $apksigner.FullName verify --print-certs $apk 2>&1 | Out-File -FilePath $log -Append -Encoding utf8

"" | Out-File -FilePath $log -Append -Encoding utf8
"=== expected signer (from new keystore) ===" | Out-File -FilePath $log -Append -Encoding utf8
& "$env:JAVA_HOME\bin\keytool.exe" -list -v -keystore C:\Users\Administrator\dogquest-release.jks -storepass 123456789101112131 -alias dogquest 2>&1 | Select-String -Pattern "Owner:|SHA1:|SHA256:" | Out-File -FilePath $log -Append -Encoding utf8

(Get-Date).ToString() | Out-File -FilePath $log -Append -Encoding utf8
"=== verify_apk_signature end ===" | Out-File -FilePath $log -Append -Encoding utf8
