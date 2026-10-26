# Removes kenv (module, PATH entry, profile lines). Environments in %USERPROFILE%\.kenv are kept.
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'kenv'
if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
$up = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($up) { [Environment]::SetEnvironmentVariable('Path', ((($up -split ';') | Where-Object { $_ -and $_ -ne $dest }) -join ';'), 'User') }
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($pf in @("$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "$docs\PowerShell\Microsoft.PowerShell_profile.ps1")) {
  if (Test-Path -LiteralPath $pf) {
    $enc = New-Object System.Text.UTF8Encoding($true)   # read/write as UTF-8 (BOM) so non-ASCII profile content survives on 5.1
    $kept = [IO.File]::ReadAllLines($pf) | Where-Object { $_ -notmatch 'kenv\\kenv\.psm1' }
    [IO.File]::WriteAllLines($pf, [string[]]@($kept), $enc)
  }
}
Write-Output "kenv removed (environments kept in $HOME\.kenv - delete manually if wanted)"
