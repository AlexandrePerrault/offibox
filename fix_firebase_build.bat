@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "fix_firebase_build.ps1"
pause
