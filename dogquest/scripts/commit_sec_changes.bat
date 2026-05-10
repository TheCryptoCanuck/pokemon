@echo off
REM Surgical commits for sec-C1 (router redirect) + sec-C1/C2 (sync service dormant marker).
REM Does NOT touch the broader untracked working tree.

cd /d C:\Users\Administrator\AviQuest-\dogquest
> scripts\commit.log echo [%date% %time%] Starting surgical commits
echo. >> scripts\commit.log

echo === current branch === >> scripts\commit.log
git branch --show-current >> scripts\commit.log 2>&1
echo. >> scripts\commit.log

echo === pre-commit status (just the two files) === >> scripts\commit.log
git status --short lib\router.dart lib\services\sighting_sync_service.dart >> scripts\commit.log 2>&1
echo. >> scripts\commit.log

echo === Commit 1: router.dart sec-C1 redirect === >> scripts\commit.log
git add lib\router.dart >> scripts\commit.log 2>&1
git commit -m "Invalidate stale offline_mode flag at every session redirect (sec-C1)" >> scripts\commit.log 2>&1
echo. >> scripts\commit.log

echo === Commit 2: sighting_sync_service.dart sec-C1 + sec-C2 === >> scripts\commit.log
git add lib\services\sighting_sync_service.dart >> scripts\commit.log 2>&1
git commit -m "Add SightingSyncService - sec-C1 auth guards, sec-C2 dormant marker" >> scripts\commit.log 2>&1
echo. >> scripts\commit.log

echo === post-commit log === >> scripts\commit.log
git log --oneline -n 5 >> scripts\commit.log 2>&1
echo. >> scripts\commit.log

echo === post-commit status (just the two files) === >> scripts\commit.log
git status --short lib\router.dart lib\services\sighting_sync_service.dart >> scripts\commit.log 2>&1
echo. >> scripts\commit.log

echo [%date% %time%] DONE >> scripts\commit.log
