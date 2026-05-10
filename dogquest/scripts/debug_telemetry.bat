@echo off
cd /d C:\Users\Administrator\AviQuest-\dogquest
> scripts\debug.log echo [%date% %time%] Debug

echo === pwd === >> scripts\debug.log
cd >> scripts\debug.log 2>&1
echo. >> scripts\debug.log

echo === dart analyze (verbose) === >> scripts\debug.log
dart analyze lib\widgets\dog_found_dialog.dart >> scripts\debug.log 2>&1
echo (analyze exit %ERRORLEVEL%) >> scripts\debug.log
echo. >> scripts\debug.log

echo === git add + commit === >> scripts\debug.log
git add lib\widgets\dog_found_dialog.dart >> scripts\debug.log 2>&1
echo (add exit %ERRORLEVEL%) >> scripts\debug.log
git commit -m "Instrument dog_found_dialog v1 telemetry (sec-E5)" >> scripts\debug.log 2>&1
echo (commit exit %ERRORLEVEL%) >> scripts\debug.log
echo. >> scripts\debug.log

echo === post-commit log === >> scripts\debug.log
git log --oneline -n 4 >> scripts\debug.log 2>&1

echo [%date% %time%] DONE >> scripts\debug.log
