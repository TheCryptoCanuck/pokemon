# Hound -- Play Store screenshot capture
# Pulls screenshots from a connected Android device/emulator via adb.
# Pauses between captures so you can navigate the app to the target screen.
#
# Usage:
#   .\scripts\capture_screenshots.ps1
#   .\scripts\capture_screenshots.ps1 -DeviceLabel "galaxy_s24"
#   .\scripts\capture_screenshots.ps1 -OnlyScreen 3
#
# Output: screenshots/raw/<deviceLabel>/S{N}_{slug}.png

param(
    [string]$DeviceLabel = "pixel7",
    [int]$OnlyScreen = 0
)

$ErrorActionPreference = "Stop"

$ADB = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $ADB)) {
    Write-Host "adb not found at $ADB" -ForegroundColor Red
    Write-Host "Install Android Platform Tools or update the ADB path in this script." -ForegroundColor Yellow
    exit 1
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot "screenshots\raw\$DeviceLabel"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Verify a device is connected
$devices = & $ADB devices | Select-Object -Skip 1 | Where-Object { $_ -match "device$" }
if (-not $devices) {
    Write-Host "No Android device connected. Start an emulator or attach a device, then retry." -ForegroundColor Red
    exit 1
}
Write-Host "Connected device: $($devices[0])" -ForegroundColor Green
Write-Host "Device label: $DeviceLabel" -ForegroundColor Cyan
Write-Host "Output: $outDir" -ForegroundColor Cyan
Write-Host ""

# Screen definitions -- order matches the marketing brief.
# Edit `prompt` to refine the click path; the script just pauses, captures, and pulls.
$screens = @(
    @{ id = 1; slug = "camera_overlay"; prompt = "Screen 1 (CAMERA + LIVE PREDICTION): Settings -> Developer -> 'Open mock screen 1'. Branded camera viewfinder with prediction card." },
    @{ id = 2; slug = "breed_result"; prompt = "Screen 2 (BREED RESULT): Go to Identify tab -> 'Search manually' -> pick 'Golden Retriever'. Dialog opens." },
    @{ id = 3; slug = "kennel"; prompt = "Screen 3 (KENNEL 47/150): Tap Kennel tab. Ensure progress shows '47 / 150'. Seed via Settings -> Developer -> 'Seed screenshot state' first." },
    @{ id = 4; slug = "profile_xp"; prompt = "Screen 4 (PROFILE XP/LEVEL): Tap Profile tab. Level 4 'Good Boy' should be visible. Scroll to show XP bar + achievements." },
    @{ id = 5; slug = "share_sheet"; prompt = "Screen 5 (SHARE): Settings -> Developer -> 'Open mock screen 5'. Branded share UI with friend avatars + social icons." },
    @{ id = 6; slug = "offline_banner"; prompt = "Screen 6 (OFFLINE): Enable airplane mode on the device. Orange 'Offline -- local mode' banner appears at top." }
)

foreach ($s in $screens) {
    if ($OnlyScreen -ne 0 -and $s.id -ne $OnlyScreen) { continue }
    if ($s.skip) {
        Write-Host "[$($s.id)] $($s.prompt)" -ForegroundColor DarkGray
        continue
    }

    Write-Host ""
    Write-Host "[$($s.id)] $($s.prompt)" -ForegroundColor Yellow
    Write-Host "Press ENTER when the screen is staged (or 's' then ENTER to skip)..." -NoNewline
    $reply = Read-Host
    if ($reply -eq "s") {
        Write-Host "Skipped." -ForegroundColor DarkGray
        continue
    }

    $remotePath = "/sdcard/hound_capture.png"
    $localPath = Join-Path $outDir ("S{0}_{1}.png" -f $s.id, $s.slug)

    & $ADB shell screencap -p $remotePath
    & $ADB pull $remotePath $localPath | Out-Null
    & $ADB shell rm $remotePath | Out-Null

    if (Test-Path $localPath) {
        $bytes = (Get-Item $localPath).Length
        Write-Host ("  Saved: {0}  ({1:N0} bytes)" -f $localPath, $bytes) -ForegroundColor Green
    } else {
        Write-Host "  FAILED to pull screenshot." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done. Raw screenshots in $outDir" -ForegroundColor Green
Write-Host "Next: frame + copy overlay in Canva/Figma (see screenshots/README.md)." -ForegroundColor Cyan
