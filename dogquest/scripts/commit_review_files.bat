@echo off
REM Commit the comprehensive-review output files added/updated this session.
REM Phases 3, 4, 5 + updated state.json. Path is relative to cwd (inside dogquest/).

cd /d C:\Users\Administrator\AviQuest-\dogquest
echo --- start --- > scripts\commit_review.log

echo === pre-commit status === >> scripts\commit_review.log
git status --short .full-review/ >> scripts\commit_review.log 2>&1
echo. >> scripts\commit_review.log

echo === git add === >> scripts\commit_review.log
git add .full-review/ >> scripts\commit_review.log 2>&1
echo (add exit %ERRORLEVEL%) >> scripts\commit_review.log
echo. >> scripts\commit_review.log

echo === staged files === >> scripts\commit_review.log
git diff --cached --stat >> scripts\commit_review.log 2>&1
echo. >> scripts\commit_review.log

echo === commit === >> scripts\commit_review.log
git commit -m "Comprehensive review phases 3-5 (testing, docs, best practices, final report)" >> scripts\commit_review.log 2>&1
echo (commit exit %ERRORLEVEL%) >> scripts\commit_review.log
echo. >> scripts\commit_review.log

echo === post-commit log === >> scripts\commit_review.log
git log --oneline -n 7 >> scripts\commit_review.log 2>&1
echo --- end --- >> scripts\commit_review.log
