# End-to-end tests for windows/kenv.psm1 (Windows PowerShell 5.1, PowerShell 7 on Windows/Linux/macOS)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'windows/kenv.psm1') -Force -DisableNameChecking
$onWin = ($env:OS -eq 'Windows_NT')
$env:KENV_HOME = Join-Path ([IO.Path]::GetTempPath()) ("kenvtest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
$W = Join-Path $env:KENV_HOME 'work'; New-Item -ItemType Directory -Force $W | Out-Null
$envs = Join-Path $env:KENV_HOME 'envs'
$kdir = if ($onWin) { Join-Path $env:APPDATA 'jupyter\kernels' } else { Join-Path $HOME '.local/share/jupyter/kernels' }
$script:pass = 0; $script:fail = 0
function Ok([string]$t, [scriptblock]$b) {
  try { $global:LASTEXITCODE = 0; $r = & $b; if ($r -eq $false -or $LASTEXITCODE) { throw "returned false / exit $LASTEXITCODE" }; $script:pass++; "PASS $t" }
  catch { $script:fail++; "FAIL $t :: $($_.Exception.Message)" }
}
function No([string]$t, [scriptblock]$b) {
  $failed = $false
  try { $global:LASTEXITCODE = 0; $null = & $b; if ($LASTEXITCODE) { $failed = $true } } catch { $failed = $true }
  if ($failed) { $script:pass++; "PASS $t" } else { $script:fail++; "FAIL $t (expected failure)" }
}
function Freeze($n) { (kenv freeze -n $n) -join "`n" }

Ok 'help' { (kenv help | Out-String) -match 'create' }
No 'unknown command' { kenv bogus }
No 'create without name' { kenv create }
No 'bad name ..\x' { kenv create '..\x' }
No 'bad name with space' { kenv create 'a b' }
Ok 'create a (3.11 + six)' { kenv create a --python 3.11 six }
No 'duplicate create' { kenv create a --python 3.11 }
No 'create bad pkg rolls back' { kenv create bad --python 3.11 this-package-does-not-exist-kenv-zzz }
Ok 'rollback removed dir' { -not (Test-Path (Join-Path $envs 'bad')) }
Ok 'create b (3.12 vuln pin)' { kenv create b --python 3.12 urllib3==1.26.5 }
Ok 'list shows both' { $l = kenv list | Out-String; ($l -match '\sa\s') -and ($l -match '\sb\s') }
No 'install no target' { kenv install six }
No 'install nonexistent env' { kenv install -n nope six }
No 'install no packages' { kenv install -n a }
Ok 'activate a' { kenv activate a; $env:VIRTUAL_ENV -eq (Join-Path $envs 'a') }
Ok 'python from env' { (Get-Command python).Source -like (Join-Path $envs 'a*') }
Ok 'install into active' { kenv install -q packaging; python -c "import packaging" }
Ok 'list marks active' { (kenv list | Out-String) -match '\*a\s' }
No 'remove active env' { kenv remove a }
Ok 'activate b while active' { kenv activate b; $ok = $env:VIRTUAL_ENV -eq (Join-Path $envs 'b'); kenv activate a; $ok }
Ok 'deactivate' { kenv deactivate; -not $env:VIRTUAL_ENV }
Ok 'export txt' { kenv export -n a -o "$W/a.txt"; $c = Get-Content "$W/a.txt"; ($c -match '^six==').Count -and ($c[1] -match '^# python: 3\.11') }
Ok 'export has no BOM' { $b = [IO.File]::ReadAllBytes("$W/a.txt"); -not ($b[0] -eq 0xEF -and $b[1] -eq 0xBB) }
Ok 'export lock' { kenv export -n a -o "$W/a.lock" --lock; (Select-String sha256 "$W/a.lock").Count -gt 0 }
No 'import missing file' { kenv import x "$W/nope.txt" }
Ok 'import txt' { kenv import a2 "$W/a.txt"; (Freeze a) -eq (Freeze a2) }
Ok 'import lock' { kenv import a3 "$W/a.lock"; (Freeze a) -eq (Freeze a3) }
Ok 'import keeps python ver' { (kenv list | Out-String) -match '\sa3\s+3\.11' }
Ok 'clone' { kenv clone b b2; (Freeze b) -eq (Freeze b2) }
No 'clone missing src' { kenv clone nope c }
No 'clone onto existing' { kenv clone a b }
Ok 'kernel' { kenv kernel -n a; Test-Path (Join-Path $kdir 'kenv-a/kernel.json') }
Ok 'audit vulnerable -> exit !=0' { kenv audit -n b | Out-Null; $c = $LASTEXITCODE; $global:LASTEXITCODE = 0; $c -ne 0 }
Ok 'audit clean -> exit 0' { kenv audit -n a | Out-Null; $LASTEXITCODE -eq 0 }
Ok 'remove + kernel cleanup' { kenv remove a; -not (Test-Path (Join-Path $envs 'a')) -and -not (Test-Path (Join-Path $kdir 'kenv-a')) }
No 'remove nonexistent' { kenv remove a }
foreach ($e in 'a2', 'a3', 'b', 'b2') { kenv remove $e | Out-Null }
Ok 'list empty' { @(kenv list).Count -eq 1 }
Remove-Item -Recurse -Force $env:KENV_HOME
"== $script:pass passed, $script:fail failed (PowerShell $($PSVersionTable.PSVersion))"
if ($script:fail) { exit 1 }
