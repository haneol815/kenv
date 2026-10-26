<#
  kenv installer for Windows 10/11 (Windows PowerShell 5.1 or PowerShell 7).
    powershell -ExecutionPolicy Bypass -File .\install.ps1
  Re-running is safe (idempotent).
#>
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'kenv'

# 1) uv
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Write-Output "Installing uv (official installer)..."
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
  if ($LASTEXITCODE) { throw "uv installation failed" }
  $env:Path = "$HOME\.local\bin;$env:Path"
}

# 2) files (+ remove 'downloaded from internet' mark so RemoteSigned allows the module)
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($f in 'kenv.psm1', 'kenv.cmd') { Copy-Item -Force -LiteralPath (Join-Path $PSScriptRoot $f) -Destination $dest }
Get-ChildItem -LiteralPath $dest | Unblock-File
New-Item -ItemType Directory -Force -Path (Join-Path $HOME '.kenv\envs') | Out-Null

# 3) user PATH (for kenv.cmd in cmd.exe) - no duplicates
$up = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @(); if ($up) { $parts = $up -split ';' | Where-Object { $_ } }
if ($parts -notcontains $dest) { [Environment]::SetEnvironmentVariable('Path', (($parts + $dest) -join ';'), 'User') }

# 4) PowerShell profiles (5.1 and 7). ASCII-only line so profile encoding never matters.
$line = 'Import-Module (Join-Path $env:LOCALAPPDATA ''kenv\kenv.psm1'') -DisableNameChecking  # kenv'
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($pf in @("$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "$docs\PowerShell\Microsoft.PowerShell_profile.ps1")) {
  New-Item -ItemType Directory -Force -Path (Split-Path $pf) | Out-Null
  $has = (Test-Path -LiteralPath $pf) -and (Select-String -LiteralPath $pf -SimpleMatch -Quiet 'kenv\kenv.psm1')
  if (-not $has) { Add-Content -LiteralPath $pf -Value $line -Encoding ASCII }
}

# 5) execution policy: profiles need RemoteSigned for the current user
try {
  $eff = Get-ExecutionPolicy
  if ($eff -in 'Restricted', 'AllSigned', 'Undefined') { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force }
} catch {
  Write-Warning "Could not set execution policy (likely enforced by Group Policy): $($_.Exception.Message). kenv.cmd still works in cmd.exe."
}
Write-Output "kenv installed to $dest. Open a NEW terminal and run: kenv list"
