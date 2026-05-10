@echo off
setlocal
set ADB=C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools\adb.exe
set OUT=C:\Users\Administrator\AviQuest-\dogquest\screenshots
set PKG=com.hound.app
set DEV=/sdcard/hound_cap.png

if not exist "%OUT%" mkdir "%OUT%"

echo [1/5] Launching app...
%ADB% shell am force-stop %PKG%
timeout /t 1 /nobreak >nul
%ADB% shell monkey -p %PKG% -c android.intent.category.LAUNCHER 1 2>nul
timeout /t 4 /nobreak >nul

echo [2/5] Identify screen...
%ADB% shell screencap -p %DEV%
%ADB% pull %DEV% "%OUT%\01_identify.png"

echo [3/5] Kennel tab (tap 2nd nav item)...
%ADB% shell input tap 290 2400
timeout /t 2 /nobreak >nul
%ADB% shell screencap -p %DEV%
%ADB% pull %DEV% "%OUT%\02_kennel.png"

echo [4/5] Profile tab (tap 3rd nav item)...
%ADB% shell input tap 450 2400
timeout /t 2 /nobreak >nul
%ADB% shell screencap -p %DEV%
%ADB% pull %DEV% "%OUT%\03_profile.png"

echo [5/5] Map tab (tap 4th nav item)...
%ADB% shell input tap 730 2400
timeout /t 2 /nobreak >nul
%ADB% shell screencap -p %DEV%
%ADB% pull %DEV% "%OUT%\04_map.png"

echo.
echo Done.
dir "%OUT%"
pause
