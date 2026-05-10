# T1 Closure — single-shot Windows automation
# Run: powershell -ExecutionPolicy Bypass -File scripts\close_t1.ps1
# Or:  double-click from File Explorer (after right-click → Run with PowerShell, or shortcut)
#
# Reads:
#   $env:SENTRY_DSN  (optional — if set, Phase 4 builds + installs the Sentry-wired APK)
#   $env:RUN_PHONE_INSTALL  (optional — set to "1" to attempt adb install in Phase 4)
#
# Writes:
#   scripts\close_t1.log  — append-only run log
#   scripts\close_t1.status.json  — machine-readable status per phase
#
# Idempotent: safe to re-run. Each phase checks its own preconditions.

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot\..
$repo = (Get-Location).Path
$logPath = "$repo\scripts\close_t1.log"
$statusPath = "$repo\scripts\close_t1.status.json"
$status = [ordered]@{}

function Log {
    param([string]$msg, [string]$tag = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "HH:mm:ss"), $tag, $msg
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

function Save-Status {
    $status | ConvertTo-Json | Set-Content -Path $statusPath
}

function Phase {
    param([string]$name, [scriptblock]$block)
    Log "── $name ──" "PHASE"
    try {
        & $block
        $status[$name] = @{ result = "ok"; at = (Get-Date).ToString("o") }
        Log "$name: OK" "PHASE"
    } catch {
        $status[$name] = @{ result = "fail"; error = "$_"; at = (Get-Date).ToString("o") }
        Log "$name: FAIL — $_" "ERROR"
        Save-Status
        throw
    }
    Save-Status
}

# ─── Header ────────────────────────────────────────────────────────────────────
"" | Set-Content -Path $logPath  # truncate prior log
Log "Starting T1 closure run at $repo" "RUN"
Log "PowerShell $($PSVersionTable.PSVersion)" "RUN"

# ─── Phase 0: Pre-flight ──────────────────────────────────────────────────────
Phase "0_preflight" {
    Log "Working tree status:"
    git status --short 2>&1 | ForEach-Object { Log "  $_" "GIT" }

    Log "Confirming git available..."
    git --version | ForEach-Object { Log "  $_" "GIT" }

    Log "Confirming flutter available..."
    flutter --version 2>&1 | Select-Object -First 2 | ForEach-Object { Log "  $_" "FLUTTER" }

    Log "Confirming dart available..."
    dart --version 2>&1 | ForEach-Object { Log "  $_" "DART" }
}

# ─── Phase 1: C3 backend/ verification ────────────────────────────────────────
Phase "1_c3_verify" {
    if (Test-Path "$repo\backend") {
        throw "backend/ directory still present on disk; expected absent."
    }
    Log "✓ backend/ absent from working tree"

    $tracked = git ls-files backend/ 2>&1
    if ($tracked) {
        Log "Stale entries in index — removing..." "WARN"
        git rm -rf backend/
        git commit -m "Archive vestigial FastAPI backend (sec-C3)"
        Log "✓ Committed sec-C3 cleanup"
    } else {
        Log "✓ backend/ absent from git index"
    }

    $count = (git log --all --oneline -- backend/ 2>&1 | Measure-Object).Count
    Log "  $count historical commits touch backend/"

    if (Select-String -Path "$repo\.gitignore" -Pattern "^backend/" -Quiet) {
        Log "✓ backend/ ignored in .gitignore"
    } else {
        Log "WARN: .gitignore does not ignore backend/" "WARN"
    }
}

# ─── Phase 2: C2 dormant-marker verify + commit ───────────────────────────────
Phase "2_c2_verify_commit" {
    Log "Formatting sighting_sync_service.dart..."
    dart format lib/services/sighting_sync_service.dart 2>&1 | ForEach-Object { Log "  $_" "DART" }

    Log "Analyzing..."
    dart analyze lib/services/sighting_sync_service.dart 2>&1 | ForEach-Object { Log "  $_" "DART" }
    if ($LASTEXITCODE -ne 0) { throw "dart analyze failed" }

    Log "Running sync_services_test.dart..."
    flutter test test/sync_services_test.dart 2>&1 | ForEach-Object { Log "  $_" "TEST" }
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed" }

    $changed = git diff --name-only -- lib/services/sighting_sync_service.dart 2>&1
    if ($changed) {
        Log "Staging + committing C2 dormant-marker..."
        git add lib/services/sighting_sync_service.dart
        git commit -m "Mark SightingSyncService dormant pending sec-C2 (sec-C2-defer)"
        Log "✓ C2 reduced-scope close committed"
    } else {
        Log "✓ C2 already committed (no diff)"
    }
}

# ─── Phase 3: Sentry wire (only if DSN provided) ──────────────────────────────
Phase "3_sentry" {
    if (-not $env:SENTRY_DSN) {
        Log "SKIP: SENTRY_DSN not set in environment. Set it and re-run, OR Phase 3 stays a no-op." "SKIP"
        $status["3_sentry"] = @{ result = "skip"; reason = "no DSN" }
        return
    }

    Log "Verifying lib/main.dart has Sentry wired..."
    if (-not (Select-String -Path "$repo\lib\main.dart" -Pattern "SentryFlutter.init" -Quiet)) {
        throw "lib/main.dart does not contain SentryFlutter.init — code edit prerequisite failed (Cowork should have edited it)"
    }
    Log "✓ Sentry init present in main.dart"

    Log "Confirming sentry_flutter in pubspec.lock..."
    if (-not (Select-String -Path "$repo\pubspec.lock" -Pattern "sentry_flutter" -Quiet)) {
        Log "Adding sentry_flutter package..."
        flutter pub add sentry_flutter 2>&1 | ForEach-Object { Log "  $_" "PUB" }
    }

    Log "Building debug APK with DSN..."
    flutter build apk --debug --dart-define=SENTRY_DSN=$env:SENTRY_DSN 2>&1 | ForEach-Object { Log "  $_" "BUILD" }
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }
    Log "✓ APK built"

    if ($env:RUN_PHONE_INSTALL -eq "1") {
        Log "Installing on connected device..."
        adb install -r build\app\outputs\flutter-apk\app-debug.apk 2>&1 | ForEach-Object { Log "  $_" "ADB" }
        adb shell am start -n com.hound.app/.MainActivity 2>&1 | ForEach-Object { Log "  $_" "ADB" }
        Log "✓ App launched on device"
    } else {
        Log "SKIP: RUN_PHONE_INSTALL not '1' — APK at build\app\outputs\flutter-apk\app-debug.apk" "SKIP"
    }

    git add lib\main.dart pubspec.yaml pubspec.lock 2>&1 | Out-Null
    $sentryDiff = git diff --cached --name-only 2>&1
    if ($sentryDiff) {
        git commit -m "Wire Sentry DSN (TASK-050)"
        Log "✓ Sentry wire committed"
    } else {
        Log "✓ Sentry wire already committed"
    }
}

# ─── Phase 4: v1 telemetry verify + commit ────────────────────────────────────
Phase "4_telemetry" {
    Log "Verifying lib/widgets/dog_found_dialog.dart has v1 telemetry..."
    if (-not (Select-String -Path "$repo\lib\widgets\dog_found_dialog.dart" -Pattern "dog_found_dialog_v1_open" -Quiet)) {
        throw "dog_found_dialog.dart missing v1 telemetry — Cowork code-edit prerequisite failed"
    }
    Log "✓ v1 telemetry markers present"

    dart format lib/widgets/dog_found_dialog.dart 2>&1 | ForEach-Object { Log "  $_" "DART" }
    dart analyze lib/widgets/dog_found_dialog.dart 2>&1 | ForEach-Object { Log "  $_" "DART" }
    if ($LASTEXITCODE -ne 0) { throw "dart analyze failed on dog_found_dialog.dart" }

    git add lib/widgets/dog_found_dialog.dart 2>&1 | Out-Null
    $telDiff = git diff --cached --name-only 2>&1
    if ($telDiff) {
        git commit -m "Instrument dog_found_dialog v1 telemetry (E5)"
        Log "✓ Telemetry committed"
    } else {
        Log "✓ Telemetry already committed"
    }
}

# ─── Phase 5: Full test suite (regression gate) ───────────────────────────────
Phase "5_full_test_suite" {
    Log "Running full test suite..."
    flutter test test/ 2>&1 | ForEach-Object { Log "  $_" "TEST" }
    if ($LASTEXITCODE -ne 0) { throw "Full test suite has failures — halt before T1 close." }
    Log "✓ Full suite green"
}

# ─── Phase 6: Status report ───────────────────────────────────────────────────
Phase "6_status" {
    Log "── T1 CLOSE STATUS ──" "DONE"
    Log "  C3 archive:        $($status['1_c3_verify'].result)" "DONE"
    Log "  C2 dormant marker: $($status['2_c2_verify_commit'].result)" "DONE"
    Log "  Sentry DSN wire:   $($status['3_sentry'].result)" "DONE"
    Log "  v1 telemetry:      $($status['4_telemetry'].result)" "DONE"
    Log "  Full suite:        $($status['5_full_test_suite'].result)" "DONE"
    Log "" "DONE"
    Log "Manual / external steps remaining:" "DONE"
    Log "  · C1 Supabase RLS verification (dashboard or supabase CLI)" "DONE"
    Log "  · On-device cluster verify (Yorkie/Poodle/Husky photos)" "DONE"
    Log "  · /comprehensive-review:full-review → Resume from where we left off" "DONE"
}

Save-Status
Log "Run complete. Log: $logPath  Status: $statusPath" "RUN"
