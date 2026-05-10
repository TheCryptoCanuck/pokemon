@echo off
cd /d "C:\Users\Administrator\AviQuest-"
echo ============ GIT STATUS ============ > deploy_check_output.txt
git status --short >> deploy_check_output.txt 2>&1
echo. >> deploy_check_output.txt
echo ============ GIT LOG -5 ============ >> deploy_check_output.txt
git log --oneline -5 >> deploy_check_output.txt 2>&1
echo. >> deploy_check_output.txt
echo ============ GIT BRANCH ============ >> deploy_check_output.txt
git branch --show-current >> deploy_check_output.txt 2>&1
echo. >> deploy_check_output.txt
echo ============ COMMITS AHEAD OF ORIGIN ============ >> deploy_check_output.txt
git rev-list --count origin/phase-1/social-backend-realtime..HEAD >> deploy_check_output.txt 2>&1
echo. >> deploy_check_output.txt

cd /d "C:\Users\Administrator\AviQuest-\dogquest"
echo ============ DART ANALYZE ============ >> ..\deploy_check_output.txt
dart analyze >> ..\deploy_check_output.txt 2>&1
echo. >> ..\deploy_check_output.txt
echo ============ DART FORMAT DRY-RUN ============ >> ..\deploy_check_output.txt
dart format --output=none . >> ..\deploy_check_output.txt 2>&1
echo. >> ..\deploy_check_output.txt
echo ============ FLUTTER PUB GET ============ >> ..\deploy_check_output.txt
flutter pub get >> ..\deploy_check_output.txt 2>&1
echo. >> ..\deploy_check_output.txt
echo ============ DONE ============ >> ..\deploy_check_output.txt
