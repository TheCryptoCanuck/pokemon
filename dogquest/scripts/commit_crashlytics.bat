@echo off
cd /d C:\Users\Administrator\AviQuest-\dogquest
set LOG=scripts\commit_crashlytics.log

echo --- start --- > %LOG%
git status --short pubspec.yaml pubspec.lock lib/main.dart android/app/build.gradle android/settings.gradle >> %LOG% 2>&1
echo --- commit --- >> %LOG%
git add pubspec.yaml pubspec.lock lib/main.dart android/app/build.gradle android/settings.gradle >> %LOG% 2>&1
git commit -m "OBS-001: wire Firebase Crashlytics (replaces Sentry as primary error reporter; Sentry remains opt-in via SENTRY_DSN)" >> %LOG% 2>&1
echo --- final log --- >> %LOG%
git log --oneline -n 5 >> %LOG% 2>&1
echo --- end --- >> %LOG%
