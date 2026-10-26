@echo off
rem cmd.exe shim. activate in cmd:  kenv activate NAME  -> calls the env's activate.bat
setlocal
set "KH=%KENV_HOME%"
if "%KH%"=="" set "KH=%USERPROFILE%\.kenv"
if /I "%~1"=="activate" ( endlocal & call "%KH%\envs\%~2\Scripts\activate.bat" & goto :eof )
if /I "%~1"=="deactivate" ( endlocal & call deactivate.bat & goto :eof )
pwsh -NoProfile -ExecutionPolicy Bypass -Command "Import-Module '%~dp0kenv.psm1'; kenv %*" 2>nul || powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Module '%~dp0kenv.psm1'; kenv %*"
