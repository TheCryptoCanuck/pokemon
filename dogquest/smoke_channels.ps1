# Verify Hound notification channels are registered on the connected device.
# Run from anywhere: powershell -ExecutionPolicy Bypass -File smoke_channels.ps1
# Or just: .\smoke_channels.ps1   (from this directory)

$adb = "C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    Write-Host "[FAIL] adb.exe not found at $adb" -ForegroundColor Red
    Write-Host "       Run 'flutter doctor -v' to find your Android SDK path."
    exit 1
}

Write-Host "[INFO] Querying notification channels on connected device..."
$dumpsys = & $adb shell dumpsys notification --noredact 2>&1 | Out-String

# Look for hound_ and dogquest_ channel IDs
$houndMatches = [regex]::Matches($dumpsys, "id=hound_[a-z_]+")
$dogquestMatches = [regex]::Matches($dumpsys, "id=dogquest_[a-z_]+")

# Also check for ones that match without the 'id=' prefix (some Android versions)
if ($houndMatches.Count -eq 0) {
    $houndMatches = [regex]::Matches($dumpsys, "(?<![a-z])hound_(streak|daily_dog|smart|lost_dog_alerts)")
}
if ($dogquestMatches.Count -eq 0) {
    $dogquestMatches = [regex]::Matches($dumpsys, "(?<![a-z])dogquest_(streak|daily_dog|smart|lost_dog_alerts)")
}

$houndIds = $houndMatches | ForEach-Object { $_.Value } | Sort-Object -Unique
$dogquestIds = $dogquestMatches | ForEach-Object { $_.Value } | Sort-Object -Unique

Write-Host ""
Write-Host "=== Hound channels found ===" -ForegroundColor Green
if ($houndIds.Count -eq 0) {
    Write-Host "  (none yet -- launch the app and let it schedule notifications first)"
} else {
    $houndIds | ForEach-Object { Write-Host "  $_" }
}

Write-Host ""
Write-Host "=== DogQuest channels found (should be EMPTY) ===" -ForegroundColor Yellow
if ($dogquestIds.Count -eq 0) {
    Write-Host "  (none -- clean rebrand)" -ForegroundColor Green
} else {
    $dogquestIds | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

Write-Host ""
if ($houndIds.Count -gt 0 -and $dogquestIds.Count -eq 0) {
    Write-Host "[PASS] Channel rebrand verified on device." -ForegroundColor Green
    exit 0
} elseif ($dogquestIds.Count -gt 0) {
    Write-Host "[FAIL] Old dogquest_* channel IDs are still registered on this device." -ForegroundColor Red
    Write-Host "       This usually means the device has stale channels from a prior install."
    Write-Host "       Uninstall the app via 'adb uninstall com.hound.app' then reinstall."
    exit 1
} else {
    Write-Host "[INCONCLUSIVE] No hound_* channels registered yet." -ForegroundColor Yellow
    Write-Host "       Launch the app on the device first, let it init, then re-run this script."
    exit 2
}
