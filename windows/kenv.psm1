# kenv - conda-like env manager on top of uv (pip/PyPI only) - PowerShell edition
# Compatible with Windows PowerShell 5.1 and PowerShell 7+.
Set-StrictMode -Version 2.0
$script:KenvVersion = '0.1.1'
$script:OnWindows = ($env:OS -eq 'Windows_NT')
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function _KHome { if ($env:KENV_HOME) { $env:KENV_HOME } else { Join-Path $HOME '.kenv' } }
function _KEnvs { $d = Join-Path (_KHome) 'envs'; if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }; (Resolve-Path -LiteralPath $d).ProviderPath }
function _KValid([string]$n) {
  if (-not $n) { throw "kenv: env name required" }
  if ($n -notmatch '^[A-Za-z0-9_][A-Za-z0-9._-]*$') { throw "kenv: invalid env name '$n' (allowed: letters, digits, . _ -; must not start with . or -)" }
}
function _KPath([string]$n) { _KValid $n; Join-Path (_KEnvs) $n }
function _KPyOf([string]$p) {
  foreach ($c in @((Join-Path $p 'Scripts\python.exe'), (Join-Path $p 'bin/python'))) { if (Test-Path -LiteralPath $c) { return $c } }
  return $null
}
function _KPy([string]$n) { $py = _KPyOf (_KPath $n); if (-not $py) { throw "kenv: env '$n' not found (see: kenv list)" }; $py }
function _KVerOf([string]$py) { (& $py -c "import sys;print('%d.%d.%d'%sys.version_info[:3])" | Out-String).Trim() }
function _KVer([string]$n) { _KVerOf (_KPy $n) }
function _KWrite([string]$path, $lines) {
  $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
  [IO.File]::WriteAllLines($full, [string[]]@($lines), $script:Utf8NoBom)   # no BOM (PS 5.1 -Encoding utf8 adds one)
}
# run a native command; never let stderr turn into terminating errors (PS 5.1); throw on non-zero exit
function _KRun {
  param([string]$Exe, [string[]]$Arguments, [switch]$Quiet, [switch]$AllowFail)
  $ErrorActionPreference = 'Continue'
  if ($Quiet) { & $Exe @Arguments 2>&1 | Out-Null } else { & $Exe @Arguments }
  $rc = $LASTEXITCODE
  if ($rc -and -not $AllowFail) { throw "kenv: '$Exe $($Arguments[0..1] -join ' ')' failed (exit $rc)" }
}
function _KUvCheck { if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { throw "kenv: uv not found in PATH (run install.ps1)" } }
function _KFreeze([string]$py) {
  $ErrorActionPreference = 'Continue'
  $out = & uv pip freeze -q --python $py
  if ($LASTEXITCODE) { throw "kenv: uv pip freeze failed" }
  @($out)
}
function _KKernelDir([string]$n) {
  $base = if ($script:OnWindows) { Join-Path $env:APPDATA 'jupyter\kernels' }
          elseif ($env:XDG_DATA_HOME) { Join-Path $env:XDG_DATA_HOME 'jupyter/kernels' }
          else { Join-Path $HOME '.local/share/jupyter/kernels' }
  Join-Path $base "kenv-$n"
}
function _KMk([string]$n, [string]$v) {
  $p = _KPath $n
  if (Test-Path -LiteralPath $p) { throw "kenv: env '$n' already exists" }
  if (-not $v) { throw "kenv: --python needs a version" }
  _KRun uv @('python', 'install', $v) -Quiet -AllowFail
  try { _KRun uv @('venv', '-q', $p, '--python', $v, '--prompt', $n) -Quiet }
  catch { if (Test-Path -LiteralPath $p) { Remove-Item -Recurse -Force -LiteralPath $p }; throw "kenv: could not create env with Python '$v'" }
  $p
}
function _KRollback([string]$p) { if ($p -and (Test-Path -LiteralPath $p)) { Remove-Item -Recurse -Force -LiteralPath $p } }
function _KSamePath([string]$a, [string]$b) {
  if (-not $a -or -not $b) { return $false }
  $a.TrimEnd('\', '/') -eq $b.TrimEnd('\', '/')   # -eq is case-insensitive (Windows paths)
}
function _KTarget([string]$n) {
  if ($n) { _KValid $n; return $n }
  if ($env:VIRTUAL_ENV -and (_KSamePath (Split-Path $env:VIRTUAL_ENV -Parent) (_KEnvs))) { return (Split-Path $env:VIRTUAL_ENV -Leaf) }
  throw "kenv: no target env: use -n NAME or activate one"
}
function _KUsage { @"
kenv $script:KenvVersion - conda-like envs on uv (pip/PyPI only)
kenv create NAME [--python 3.x] [pkgs...]   create env
kenv activate NAME | deactivate
kenv list                                    (* = active)
kenv install [-n NAME] pkgs...|-r file       (uv pip install)
kenv uninstall [-n NAME] pkgs...
kenv freeze [-n NAME]
kenv export [-n NAME] [-o FILE] [--lock]
kenv import NAME FILE [--python 3.x]
kenv clone SRC DST
kenv kernel [-n NAME]
kenv audit [-n NAME]                         (exit code 1 if vulnerable)
kenv remove NAME
kenv python list|install VER
"@ }

<#
.SYNOPSIS
  conda-like virtual environment manager on top of uv (pip/PyPI only). Run 'kenv help'.
#>
function kenv {
  $ErrorActionPreference = 'Stop'
  $global:LASTEXITCODE = 0
  $cmd = if ($args.Count) { [string]$args[0] } else { 'help' }
  $name = $null; $rest = @()
  for ($i = 1; $i -lt $args.Count; $i++) {
    if ($args[$i] -in '-n', '--name') { if ($i + 1 -ge $args.Count) { throw "kenv: -n needs a value" }; $name = [string]$args[++$i] }
    else { $rest += [string]$args[$i] }
  }
  if ($cmd -notin 'help', '-h', '--help', 'version', '--version', 'deactivate') { _KUvCheck }
  switch ($cmd) {
    'create' {
      if ($rest.Count -lt 1) { throw "kenv: usage: kenv create NAME [--python 3.x] [pkgs...]" }
      $n = $rest[0]; _KValid $n; $v = '3.12'; $pk = @()
      for ($i = 1; $i -lt $rest.Count; $i++) {
        if ($rest[$i] -in '--python', '-p') { if ($i + 1 -ge $rest.Count) { throw "kenv: --python needs a version" }; $v = $rest[++$i] }
        else { $pk += $rest[$i] } }
      $p = _KMk $n $v
      if ($pk.Count) { try { _KRun uv (@('pip', 'install', '-q', '--python', (_KPy $n)) + $pk) } catch { _KRollback $p; throw "kenv: package install failed; env '$n' rolled back" } }
      "created '$n' (Python $(_KVer $n)) -> $p"; break }
    { $_ -in 'list', 'ls', 'env' } {
      '{0,-20} {1,-10} {2}' -f 'NAME', 'PYTHON', 'PATH'
      foreach ($d in @(Get-ChildItem -Directory -LiteralPath (_KEnvs))) {
        $py = _KPyOf $d.FullName; if (-not $py) { continue }
        $m = if (_KSamePath $env:VIRTUAL_ENV $d.FullName) { '*' } else { ' ' }
        '{0,-20} {1,-10} {2}' -f ($m + $d.Name), (_KVerOf $py), $d.FullName }
      break }
    'activate' {
      if ($rest.Count -lt 1) { throw "kenv: usage: kenv activate NAME" }
      $p = _KPath $rest[0]; $null = _KPy $rest[0]
      if ($env:VIRTUAL_ENV -and (Get-Command deactivate -ErrorAction SilentlyContinue)) { deactivate }
      $a = @((Join-Path $p 'Scripts\activate.ps1'), (Join-Path $p 'bin/activate.ps1')) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
      if (-not $a) { throw "kenv: activate.ps1 not found in $p" }
      . $a; break }
    'deactivate' { if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate } else { Write-Warning "kenv: no active env" }; break }
    { $_ -in 'install', 'add' } { if (-not $rest.Count) { throw "kenv: nothing to install" }; $t = _KTarget $name; _KRun uv (@('pip', 'install', '--python', (_KPy $t)) + $rest); break }
    'uninstall' { if (-not $rest.Count) { throw "kenv: nothing to uninstall" }; $t = _KTarget $name; _KRun uv (@('pip', 'uninstall', '--python', (_KPy $t)) + $rest); break }
    'freeze' { $t = _KTarget $name; _KFreeze (_KPy $t); break }
    'export' {
      $t = _KTarget $name; $out = $null; $lock = $false
      for ($i = 0; $i -lt $rest.Count; $i++) {
        if ($rest[$i] -eq '-o') { if ($i + 1 -ge $rest.Count) { throw "kenv: -o needs a file" }; $out = $rest[++$i] }
        elseif ($rest[$i] -eq '--lock') { $lock = $true } else { throw "kenv: unknown option: $($rest[$i])" } }
      $py = _KPy $t; $ver = _KVerOf $py; $lines = @("# kenv-env: $t", "# python: $ver")
      $frz = _KFreeze $py
      if ($lock) {
        $tmp = [IO.Path]::GetTempFileName(); _KWrite $tmp $frz
        $ErrorActionPreference = 'Continue'
        $lk = & uv pip compile -q $tmp --python-version ($ver -replace '\.\d+$', '') --generate-hashes --no-header
        $rc = $LASTEXITCODE; $ErrorActionPreference = 'Stop'; Remove-Item -LiteralPath $tmp
        if ($rc) { throw "kenv: lock failed" }
        $lines += $lk
      } else { $lines += $frz }
      if ($out) { _KWrite $out $lines; "exported '$t' -> $out" } else { $lines }
      break }
    'import' {
      if ($rest.Count -lt 2) { throw "kenv: usage: kenv import NAME FILE [--python 3.x]" }
      $n = $rest[0]; $f = $rest[1]; _KValid $n
      if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { throw "kenv: file not found: $f" }
      $v = $null
      $mm = Select-String -LiteralPath $f -Pattern '^# python: (.+)$' | Select-Object -First 1
      if ($mm) { $v = $mm.Matches[0].Groups[1].Value.Trim() }
      if ($rest.Count -ge 3 -and $rest[2] -eq '--python') { if ($rest.Count -lt 4) { throw "kenv: --python needs a version" }; $v = $rest[3] }
      if (-not $v) { $v = '3.12' }
      $p = _KMk $n $v
      try { _KRun uv @('pip', 'sync', '-q', '--python', (_KPy $n), $f) } catch { _KRollback $p; throw "kenv: sync failed; env '$n' rolled back" }
      "imported '$n' (Python $(_KVer $n)) from $f"; break }
    'clone' {
      if ($rest.Count -lt 2) { throw "kenv: usage: kenv clone SRC DST" }
      $s = $rest[0]; $d = $rest[1]; $spy = _KPy $s
      $tmp = [IO.Path]::GetTempFileName(); _KWrite $tmp (_KFreeze $spy)
      try {
        $p = _KMk $d (_KVerOf $spy)
        try { _KRun uv @('pip', 'sync', '-q', '--python', (_KPy $d), $tmp) } catch { _KRollback $p; throw "kenv: clone failed; rolled back" }
      } finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
      "cloned '$s' -> '$d'"; break }
    'kernel' {
      $t = _KTarget $name; $py = _KPy $t
      _KRun uv @('pip', 'install', '-q', '--python', $py, 'ipykernel')
      _KRun $py @('-m', 'ipykernel', 'install', '--user', '--name', "kenv-$t", '--display-name', "Python $(_KVerOf $py) (kenv: $t)"); break }
    'audit' {
      $t = _KTarget $name; $tmp = [IO.Path]::GetTempFileName(); _KWrite $tmp (_KFreeze (_KPy $t))
      try { _KRun uvx @('-q', 'pip-audit', '-r', $tmp, '--no-deps', '--disable-pip', '--progress-spinner', 'off') -AllowFail; $rc = $LASTEXITCODE }
      finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
      $global:LASTEXITCODE = $rc; break }
    { $_ -in 'remove', 'rm' } {
      if ($rest.Count -lt 1) { throw "kenv: usage: kenv remove NAME" }
      $p = _KPath $rest[0]; $null = _KPy $rest[0]
      if (_KSamePath $env:VIRTUAL_ENV $p) { throw "kenv: env '$($rest[0])' is active; run 'kenv deactivate' first" }
      Remove-Item -Recurse -Force -LiteralPath $p
      $k = _KKernelDir $rest[0]; if (Test-Path -LiteralPath $k) { Remove-Item -Recurse -Force -LiteralPath $k }
      "removed '$($rest[0])'"; break }
    'python' { _KRun uv (@('python') + $rest); break }
    'prefix' { if ($rest.Count -lt 1) { throw "kenv: usage: kenv prefix NAME" }; $null = _KPy $rest[0]; _KPath $rest[0]; break }
    { $_ -in 'version', '--version' } { "kenv $script:KenvVersion"; break }
    { $_ -in 'help', '-h', '--help' } { _KUsage; break }
    default { _KUsage; throw "kenv: unknown command: $cmd" }
  }
}
Export-ModuleMember -Function kenv
