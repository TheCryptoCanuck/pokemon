@echo off
echo === Building Hound (debug APK) ===
cd /d "%~dp0"

echo Checking for connected devices...
adb devices

echo.
echo Building debug APK...
call flutter build apk --debug ^
  --dart-define=API_BASE_URL=https://example.com ^
  --dart-define=SUPABASE_URL=https://example.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=placeholder

if %ERRORLEVEL% NEQ 0 (
    echo BUILD FAILED
    pause
    exit /b 1
)

echo.
echo Installing on emulator...
adb install -r build\app\outputs\flutter-apk\app-debug.apk

if %ERRORLEVEL% NEQ 0 (
    echo INSTALL FAILED
    pause
    exit /b 1
)

echo.
echo Launching app...
adb shell am start -n com.hound.app/.MainActivity

echo.
echo === Done! App should be running on emulator ===
pause
