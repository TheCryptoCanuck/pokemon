@echo off
REM Restores files Cowork accidentally truncated during dart format on a full disk.
REM Writes a status log to scripts\restore.log.

cd /d C:\Users\Administrator\AviQuest-\dogquest
> scripts\restore.log echo [%date% %time%] Starting restore
echo. >> scripts\restore.log

echo === git status BEFORE checkout === >> scripts\restore.log
git status --short lib\services\sighting_sync_service.dart pubspec.yaml >> scripts\restore.log 2>&1
echo. >> scripts\restore.log

echo === git diff stat (count of lines changed) === >> scripts\restore.log
git diff --stat lib\services\sighting_sync_service.dart pubspec.yaml >> scripts\restore.log 2>&1
echo. >> scripts\restore.log

echo === checking out HEAD versions === >> scripts\restore.log
git checkout HEAD -- lib\services\sighting_sync_service.dart pubspec.yaml >> scripts\restore.log 2>&1
echo. >> scripts\restore.log

echo === post-restore line counts === >> scripts\restore.log
for /f %%A in ('find /c /v "" ^< lib\services\sighting_sync_service.dart') do echo sighting_sync_service.dart: %%A lines >> scripts\restore.log
for /f %%A in ('find /c /v "" ^< pubspec.yaml') do echo pubspec.yaml: %%A lines >> scripts\restore.log
echo. >> scripts\restore.log

echo === post-restore git status === >> scripts\restore.log
git status --short lib\services\sighting_sync_service.dart pubspec.yaml >> scripts\restore.log 2>&1
echo. >> scripts\restore.log

echo [%date% %time%] DONE >> scripts\restore.log
