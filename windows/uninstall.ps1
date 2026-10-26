$dest = Join-Path $env:LOCALAPPDATA 'kenv'
Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
$up = [Environment]::GetEnvironmentVariable('Path', 'User')
[Environment]::SetEnvironmentVariable('Path', (($up -split ';') | Where-Object { $_ -and $_ -ne $dest }) -join ';', 'User')
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($pf in @("$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "$docs\PowerShell\Microsoft.PowerShell_profile.ps1")) {
  if (Test-Path $pf) { (Get-Content $pf) | Where-Object { $_ -notmatch 'kenv\.psm1' } | Set-Content $pf } }
Write-Host "kenv removed (envs kept in $HOME\.kenv - delete manually if wanted)"
