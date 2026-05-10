@echo off
setlocal
set ADB=C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools\adb.exe
set OUT=C:\Users\Administrator\AviQuest-\dogquest\screenshots
set PKG=com.hound.app
set DEV=/sdcard/hound_cap.png

REM Get real screen dimensions
%ADB% shell wm size

echo Launching app...
%ADB% shell monkey -p %PKG% -c android.intent.category.LAUNCHER 1 2>nul
timeout /t 3 /nobreak >nul

REM Tap Me tab — rightmost of 5, ~972px on 1080px wide screen, Y~2430
echo Tapping Me tab (rightmost nav item)...
%ADB% shell input tap 972 2430
timeout /t 2 /nobreak >nul
%ADB% shell screencap -p %DEV%
%ADB% pull %DEV% "%OUT%\05_profile_me.png"

REM Also grab Sightings tab — leftmost
echo Tapping Sightings tab (leftmost nav item)...
%ADB% shell input tap 108 2430
timeout /t 2 /nobreak >nul
%ADB% shell screencap -p %DEV%
%ADB% pull %DEV% "%OUT%\06_sightings.png"

echo Done.
dir "%OUT%"
pause
