@echo off
set LOG=C:\Users\Administrator\AviQuest-\dogquest\scripts\generate_keystore.log
set KEYTOOL="C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
set JKS=C:\Users\Administrator\dogquest-release.jks
set PWD=123456789101112131

echo --- start --- > %LOG%
echo target: %JKS% >> %LOG%

REM Generate the keystore non-interactively
%KEYTOOL% -genkey -v -keystore %JKS% -keyalg RSA -keysize 2048 -validity 10000 -alias dogquest -storepass %PWD% -keypass %PWD% -dname "CN=DogQuest, OU=Dev, O=DogQuest, L=Berlin, ST=BE, C=DE" >> %LOG% 2>&1
echo --- after keytool, errorlevel=%ERRORLEVEL% --- >> %LOG%

REM Verify the file exists
if exist %JKS% (
    echo VERIFY: keystore exists at %JKS% >> %LOG%
    dir %JKS% >> %LOG% 2>&1
) else (
    echo VERIFY: keystore NOT FOUND at %JKS% >> %LOG%
)
echo --- end --- >> %LOG%
