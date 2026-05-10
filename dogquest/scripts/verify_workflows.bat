@echo off
cd /d C:\Users\Administrator\AviQuest-
set LOG=dogquest\scripts\verify_workflows.log

echo --- start --- > %LOG%
echo === workflow files === >> %LOG%
dir .github\workflows\ >> %LOG% 2>&1
echo. >> %LOG%
echo === aviquest-ci.yml first 15 lines === >> %LOG%
powershell -Command "Get-Content '.github\workflows\aviquest-ci.yml' -TotalCount 15" >> %LOG% 2>&1
echo. >> %LOG%
echo === dogquest-ci.yml first 15 lines === >> %LOG%
powershell -Command "Get-Content '.github\workflows\dogquest-ci.yml' -TotalCount 15" >> %LOG% 2>&1
echo --- end --- >> %LOG%
