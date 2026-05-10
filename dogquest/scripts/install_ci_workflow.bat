@echo off
REM Moves dogquest/.github/workflows/ci.yml up to the git repo root's .github/workflows/,
REM where GitHub Actions actually reads it. Deletes the misplaced dogquest/.github/ copy.

cd /d C:\Users\Administrator\AviQuest-
set LOG=dogquest\scripts\install_ci_workflow.log

echo --- start --- > %LOG%
echo cwd: %CD% >> %LOG%

REM Create .github/workflows at repo root
if not exist ".github\workflows" mkdir ".github\workflows"
echo --- created .github/workflows --- >> %LOG%

REM Copy the workflow file up
copy /Y "dogquest\.github\workflows\ci.yml" ".github\workflows\ci.yml" >> %LOG% 2>&1
echo --- copied ci.yml --- >> %LOG%

REM Remove the misplaced copy in dogquest/
rmdir /S /Q "dogquest\.github" >> %LOG% 2>&1
echo --- removed dogquest/.github --- >> %LOG%

REM Stage + commit
git add .github\workflows\ci.yml >> %LOG% 2>&1
git commit -m "OPS-001: GitHub Actions CI workflow (format + analyze + test + debug-apk artifact)" >> %LOG% 2>&1
echo --- final log --- >> %LOG%
git log --oneline -n 3 >> %LOG% 2>&1
echo --- end --- >> %LOG%
