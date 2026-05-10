@echo off
cd /d C:\Users\Administrator\AviQuest-\dogquest
> scripts\state.log echo [%date% %time%] Working-tree audit
echo. >> scripts\state.log

echo === git status (full) === >> scripts\state.log
git status --short >> scripts\state.log 2>&1
echo. >> scripts\state.log

echo === git log (last 5) === >> scripts\state.log
git log --oneline -n 5 >> scripts\state.log 2>&1
echo. >> scripts\state.log

echo === current branch === >> scripts\state.log
git branch --show-current >> scripts\state.log 2>&1
echo. >> scripts\state.log

echo === remote? === >> scripts\state.log
git remote -v >> scripts\state.log 2>&1
echo. >> scripts\state.log

echo === sec-C3 backend tracking === >> scripts\state.log
git ls-files backend/ >> scripts\state.log 2>&1
echo. >> scripts\state.log
git log --all --oneline -- backend/ | findstr /n "^" | findstr /b "[1-5]:" >> scripts\state.log 2>&1
echo. >> scripts\state.log

echo === current toolchain versions === >> scripts\state.log
flutter --version >> scripts\state.log 2>&1
echo. >> scripts\state.log
dart --version >> scripts\state.log 2>&1
echo. >> scripts\state.log

echo [%date% %time%] DONE >> scripts\state.log
