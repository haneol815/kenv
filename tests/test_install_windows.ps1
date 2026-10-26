# Windows only: install.ps1 (twice, idempotent) -> profile/PATH -> kenv.cmd in cmd.exe -> uninstall.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Check($t, $c) { if (-not $c) { throw "FAIL $t" } ; "PASS $t" }
& (Join-Path $root 'windows\install.ps1'); & (Join-Path $root 'windows\install.ps1')
$dest = Join-Path $env:LOCALAPPDATA 'kenv'
$up = [Environment]::GetEnvironmentVariable('Path', 'User')
Check 'files installed' (Test-Path "$dest\kenv.psm1")
Check 'PATH once' ((($up -split ';') | Where-Object { $_ -eq $dest }).Count -eq 1)
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($pf in "$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "$docs\PowerShell\Microsoft.PowerShell_profile.ps1") {
  Check "profile line once: $pf" (@(Select-String -LiteralPath $pf -SimpleMatch 'kenv\kenv.psm1').Count -eq 1) }
$env:KENV_HOME = Join-Path $env:TEMP 'kenv-inst'
# new PowerShell 5.1 and 7 sessions load kenv from the profile
foreach ($sh in 'powershell', 'pwsh') {
  $o = & $sh -NoLogo -Command "kenv version" 2>&1 | Out-String
  Check "$sh profile loads kenv" ($o -match 'kenv 0\.')
}
# cmd.exe shim: create, activate, deactivate, exit codes
$bat = Join-Path $env:TEMP 'kenvtest.cmd'
@"
@echo off
set "PATH=$dest;%PATH%"
call kenv create c1 --python 3.12 six || exit /b 11
call kenv activate c1 || exit /b 12
python -c "import six, sys; assert 'c1' in sys.prefix" || exit /b 13
call kenv deactivate || exit /b 14
call kenv remove nope && exit /b 15
call kenv activate nope && exit /b 16
call kenv remove c1 || exit /b 17
echo CMD_OK
"@ | Set-Content -Encoding ASCII $bat
$o = cmd /c $bat 2>&1 | Out-String; $rc = $LASTEXITCODE
Write-Output $o
Check "kenv.cmd flow (rc=$rc)" ($rc -eq 0 -and $o -match 'CMD_OK')
& (Join-Path $root 'windows\uninstall.ps1')
$up = [Environment]::GetEnvironmentVariable('Path', 'User')
Check 'uninstalled files' (-not (Test-Path $dest))
Check 'PATH cleaned' (-not (($up -split ';') -contains $dest))
foreach ($pf in "$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "$docs\PowerShell\Microsoft.PowerShell_profile.ps1") {
  Check "profile cleaned: $pf" (-not (Select-String -LiteralPath $pf -SimpleMatch -Quiet 'kenv\kenv.psm1')) }
& (Join-Path $root 'windows\install.ps1')
Check 'reinstall' (Test-Path "$dest\kenv.psm1")
"install tests passed"
