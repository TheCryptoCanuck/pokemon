@echo off
REM Verify + commit the v1 telemetry instrumentation in dog_found_dialog.dart.

cd /d C:\Users\Administrator\AviQuest-\dogquest
> scripts\telemetry.log echo [%date% %time%] Verifying telemetry edits
echo. >> scripts\telemetry.log

echo === dart format === >> scripts\telemetry.log
dart format lib\widgets\dog_found_dialog.dart >> scripts\telemetry.log 2>&1
echo. >> scripts\telemetry.log

echo === dart analyze === >> scripts\telemetry.log
dart analyze lib\widgets\dog_found_dialog.dart >> scripts\telemetry.log 2>&1
set ANALYZE_RC=%ERRORLEVEL%
echo (analyze exit code %ANALYZE_RC%) >> scripts\telemetry.log
echo. >> scripts\telemetry.log

if %ANALYZE_RC% NEQ 0 (
    echo HALT: dart analyze failed. Skipping flutter test and commit. >> scripts\telemetry.log
    echo [%date% %time%] DONE (analyze fail) >> scripts\telemetry.log
    goto :end
)

echo === flutter test (focused) === >> scripts\telemetry.log
flutter test test\sync_services_test.dart >> scripts\telemetry.log 2>&1
set TEST_RC=%ERRORLEVEL%
echo (flutter test exit code %TEST_RC%) >> scripts\telemetry.log
echo. >> scripts\telemetry.log

echo === git status before commit === >> scripts\telemetry.log
git status --short lib\widgets\dog_found_dialog.dart >> scripts\telemetry.log 2>&1
echo. >> scripts\telemetry.log

echo === Commit telemetry === >> scripts\telemetry.log
git add lib\widgets\dog_found_dialog.dart >> scripts\telemetry.log 2>&1
git commit -m "Instrument dog_found_dialog v1 telemetry (sec-E5)" >> scripts\telemetry.log 2>&1
echo. >> scripts\telemetry.log

echo === post-commit log === >> scripts\telemetry.log
git log --oneline -n 6 >> scripts\telemetry.log 2>&1
echo. >> scripts\telemetry.log

:end
echo [%date% %time%] DONE >> scripts\telemetry.log
