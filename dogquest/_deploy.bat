@echo off
cd /d %~dp0
flutter build apk --debug ^
  --dart-define=API_BASE_URL=https://example.com ^
  --dart-define=SUPABASE_URL=https://example.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=placeholder && ^
C:\Users\Administrator\AppData\Local\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk && ^
C:\Users\Administrator\AppData\Local\Android\Sdk\platform-tools\adb.exe shell am start -n com.hound.app/.MainActivity
echo Done.
pause
