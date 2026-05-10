@echo off
cd /d C:\Users\Administrator\AviQuest-\dogquest
echo --- start --- > scripts\just_commit.log
git log --oneline -n 4 >> scripts\just_commit.log 2>&1
echo --- after-log --- >> scripts\just_commit.log
git status --short lib\widgets\dog_found_dialog.dart >> scripts\just_commit.log 2>&1
echo --- after-status --- >> scripts\just_commit.log
git add lib\widgets\dog_found_dialog.dart >> scripts\just_commit.log 2>&1
echo --- after-add --- >> scripts\just_commit.log
git commit -m "Instrument dog_found_dialog v1 telemetry (sec-E5)" >> scripts\just_commit.log 2>&1
echo --- after-commit --- >> scripts\just_commit.log
git log --oneline -n 5 >> scripts\just_commit.log 2>&1
echo --- end --- >> scripts\just_commit.log
