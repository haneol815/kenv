@echo off
rem kenv shim for cmd.exe.  "kenv activate NAME" / "kenv deactivate" use the env's .bat scripts;
rem everything else is forwarded to the PowerShell module and its exit code is returned.
setlocal
set "KH=%KENV_HOME%"
if "%KH%"=="" set "KH=%USERPROFILE%\.kenv"
if /I "%~1"=="activate" goto :activate
if /I "%~1"=="deactivate" goto :deactivate
set "PSEXE=powershell"
where pwsh >nul 2>nul && set "PSEXE=pwsh"
%PSEXE% -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Import-Module '%~dp0kenv.psm1'; try { kenv %* } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }; exit $LASTEXITCODE"
exit /b %ERRORLEVEL%

:activate
if "%~2"=="" ( echo kenv: usage: kenv activate NAME 1>&2 & exit /b 1 )
if not exist "%KH%\envs\%~2\Scripts\activate.bat" ( echo kenv: env '%~2' not found 1>&2 & exit /b 1 )
endlocal & call "%KH%\envs\%~2\Scripts\activate.bat"
goto :eof

:deactivate
endlocal
if not defined VIRTUAL_ENV ( echo kenv: no active env 1>&2 & exit /b 1 )
call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
goto :eof
