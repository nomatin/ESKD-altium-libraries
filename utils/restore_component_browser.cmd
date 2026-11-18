@echo off
setlocal
if "%~1"=="" goto latest
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure_component_browser.ps1" -Restore "%~1"
exit /b %errorlevel%
:latest
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure_component_browser.ps1" -RestoreLatest
exit /b %errorlevel%
