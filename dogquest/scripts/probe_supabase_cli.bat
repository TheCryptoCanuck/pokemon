@echo off
cd /d C:\Users\Administrator\AviQuest-\dogquest
> scripts\supabase_probe.log echo [%date% %time%] Probing Supabase CLI
echo. >> scripts\supabase_probe.log

echo === supabase CLI on PATH? === >> scripts\supabase_probe.log
where supabase >> scripts\supabase_probe.log 2>&1
echo. >> scripts\supabase_probe.log

echo === supabase --version === >> scripts\supabase_probe.log
supabase --version >> scripts\supabase_probe.log 2>&1
echo. >> scripts\supabase_probe.log

echo === existing project link? === >> scripts\supabase_probe.log
supabase projects list >> scripts\supabase_probe.log 2>&1
echo. >> scripts\supabase_probe.log

echo === look for any local supabase config === >> scripts\supabase_probe.log
if exist supabase\config.toml ( echo found supabase\config.toml >> scripts\supabase_probe.log ) else ( echo no supabase\config.toml >> scripts\supabase_probe.log )
if exist .supabase\ ( echo found .supabase\ dir >> scripts\supabase_probe.log ) else ( echo no .supabase\ dir >> scripts\supabase_probe.log )
echo. >> scripts\supabase_probe.log

echo === any .sql files referencing sync_sightings? === >> scripts\supabase_probe.log
findstr /s /m "sync_sightings" *.sql 2>>scripts\supabase_probe.log
findstr /s /m "sync_sightings" supabase\*.sql 2>>scripts\supabase_probe.log
echo. >> scripts\supabase_probe.log

echo [%date% %time%] DONE >> scripts\supabase_probe.log
