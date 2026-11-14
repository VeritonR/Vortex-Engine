@echo off
rem Builds the Android APK: double click it. The finished APK goes to export\VortexEngine-android.apk
rem   build_android.bat -Clean     builds everything again from scratch
rem   build_android.bat -Install   also installs it on the phone plugged in by USB
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup\android\build_android.ps1" %*
set RESULT=%errorlevel%
rem (a window opened with a double click stays open to show what happened)
echo %cmdcmdline% | "%SystemRoot%\System32\find.exe" /i "%~nx0" >nul && pause
exit /b %RESULT%
