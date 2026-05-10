@echo off
cd /d C:\Users\Administrator\AviQuest-\dogquest
set LOG=scripts\commit_doc002.log

echo --- start --- > %LOG%
git status --short README.md >> %LOG% 2>&1
git diff --stat README.md >> %LOG% 2>&1
echo --- commit --- >> %LOG%
git add README.md >> %LOG% 2>&1
git commit -m "DOC-002: add README.md at project root (quick start, tech stack, structure, docs index, ML notes, status, license placeholder)" >> %LOG% 2>&1
echo --- final log --- >> %LOG%
git log --oneline -n 3 >> %LOG% 2>&1
echo --- end --- >> %LOG%
