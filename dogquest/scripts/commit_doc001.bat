@echo off
cd /d C:\Users\Administrator\AviQuest-\dogquest
set LOG=scripts\commit_doc001.log

echo --- start --- > %LOG%
git status --short CLAUDE.md >> %LOG% 2>&1
git diff --stat CLAUDE.md >> %LOG% 2>&1
echo --- commit --- >> %LOG%
git add CLAUDE.md >> %LOG% 2>&1
git commit -m "DOC-001: reconcile CLAUDE.md ML spec drift; deployed=150 breeds (v5.1), target=294 (v6); fix screen/service/test/widget counts" >> %LOG% 2>&1
echo --- final log --- >> %LOG%
git log --oneline -n 3 >> %LOG% 2>&1
echo --- end --- >> %LOG%
