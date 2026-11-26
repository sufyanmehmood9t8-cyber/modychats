@echo off
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
cd /d C:\Users\kc\modychat\android
call gradlew.bat assembleDebug --console=plain > C:\Users\kc\modychat\gradle_build.log 2>&1
echo EXITCODE=%ERRORLEVEL% >> C:\Users\kc\modychat\gradle_build.log
