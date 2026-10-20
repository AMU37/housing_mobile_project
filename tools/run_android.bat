@echo off
setlocal
cd /d "%~dp0\.."
if not exist "android\app\src\main\AndroidManifest.xml" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "tools\setup_android.ps1"
  if errorlevel 1 exit /b 1
)
flutter pub get
if errorlevel 1 exit /b 1
flutter run
