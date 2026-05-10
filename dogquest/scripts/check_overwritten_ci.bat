@echo off
cd /d C:\Users\Administrator\AviQuest-
set LOG=dogquest\scripts\check_overwritten_ci.log

echo --- start --- > %LOG%
echo === previous version (HEAD~1) === >> %LOG%
git show HEAD~1:.github/workflows/ci.yml >> %LOG% 2>&1
echo. >> %LOG%
echo === current version (HEAD) === >> %LOG%
git show HEAD:.github/workflows/ci.yml >> %LOG% 2>&1
echo --- end --- >> %LOG%
