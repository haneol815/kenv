# kenv installer for Windows 11 (PowerShell 5.1 / 7).  Run:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'kenv'
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Write-Host "Installing uv (official installer)..."
  powershell -ExecutionPolicy ByPass -NoProfile -c "irm https://astral.sh/uv/install.ps1 | iex"
  $env:Path = "$HOME\.local\bin;$env:Path"
}
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item -Force (Join-Path $PSScriptRoot 'kenv.psm1'), (Join-Path $PSScriptRoot 'kenv.cmd') $dest
New-Item -ItemType Directory -Force (Join-Path $HOME '.kenv\envs') | Out-Null
# user PATH (for kenv.cmd in cmd.exe)
$up = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($up -split ';') -notcontains $dest) { [Environment]::SetEnvironmentVariable('Path', "$up;$dest", 'User') }
# PowerShell profiles (5.1 and 7)
$line = "Import-Module '$dest\kenv.psm1' -DisableNameChecking"
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($pf in @("$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "$docs\PowerShell\Microsoft.PowerShell_profile.ps1")) {
  New-Item -ItemType Directory -Force (Split-Path $pf) | Out-Null
  if (-not (Test-Path $pf) -or -not (Select-String -Quiet -SimpleMatch $line $pf)) { Add-Content $pf $line }
}
# profile scripts need RemoteSigned for the current user
if ((Get-ExecutionPolicy -Scope CurrentUser) -in 'Undefined', 'Restricted') { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force }
Write-Host "kenv installed to $dest. Open a new terminal and run: kenv list"
