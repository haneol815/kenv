# kenv - conda-like env manager on top of uv (pip/PyPI only) - PowerShell edition
$ErrorActionPreference = 'Stop'
function _KHome { if ($env:KENV_HOME) { $env:KENV_HOME } else { Join-Path $HOME '.kenv' } }
function _KEnvs { $d = Join-Path (_KHome) 'envs'; New-Item -ItemType Directory -Force $d | Out-Null; $d }
function _KPath([string]$n) { if (-not $n) { throw "kenv: env name required" }; Join-Path (_KEnvs) $n }
function _KPy([string]$n) {
  $p = _KPath $n
  foreach ($c in @((Join-Path $p 'Scripts\python.exe'), (Join-Path $p 'bin/python'))) { if (Test-Path $c) { return $c } }
  throw "kenv: env '$n' not found"
}
function _KVer([string]$n) { & (_KPy $n) -c "import sys;print('%d.%d.%d'%sys.version_info[:3])" }
function _KUv { if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { throw "kenv: uv not found (run install.ps1)" }
  & uv @args; if ($LASTEXITCODE) { throw "kenv: uv $($args[0]) failed ($LASTEXITCODE)" } }
function _KKernelDir([string]$n) {
  $base = if ($IsWindows -or $env:OS -eq 'Windows_NT') { Join-Path $env:APPDATA 'jupyter\kernels' }
          else { Join-Path ($(if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { "$HOME/.local/share" })) 'jupyter/kernels' }
  Join-Path $base "kenv-$n"
}
function _KMk([string]$n, [string]$v) {
  if (Test-Path (_KPath $n)) { throw "kenv: env '$n' exists" }
  & uv python install $v *> $null
  _KUv venv -q (_KPath $n) --python $v --prompt $n
}
function _KTarget([string]$n) {
  if ($n) { return $n }
  if ($env:VIRTUAL_ENV -and ((Split-Path $env:VIRTUAL_ENV -Parent) -eq (_KEnvs))) { return Split-Path $env:VIRTUAL_ENV -Leaf }
  throw "kenv: no env: use -n NAME or activate one"
}
function _KUsage { @'
kenv create NAME [--python 3.x] [pkgs...]   create env
kenv activate NAME | deactivate
kenv list
kenv install [-n NAME] pkgs...|-r file      (uv pip install)
kenv uninstall [-n NAME] pkgs...
kenv freeze [-n NAME]
kenv export [-n NAME] [-o FILE] [--lock]
kenv import NAME FILE [--python 3.x]
kenv clone SRC DST
kenv kernel [-n NAME]
kenv audit [-n NAME]
kenv remove NAME
kenv python list|install VER
'@ }

function kenv {
  $cmd = if ($args.Count) { [string]$args[0] } else { 'help' }
  $name = $null; $rest = @()
  for ($i = 1; $i -lt $args.Count; $i++) {
    if ($args[$i] -in '-n', '--name') { $name = $args[++$i] } else { $rest += [string]$args[$i] }
  }
  switch ($cmd) {
    'create' {
      $n = $rest[0]; $v = '3.12'; $pk = @()
      for ($i = 1; $i -lt $rest.Count; $i++) { if ($rest[$i] -in '--python', '-p') { $v = $rest[++$i] } else { $pk += $rest[$i] } }
      _KMk $n $v
      if ($pk.Count) { _KUv pip install -q --python (_KPy $n) @pk }
      "created '$n' (Python $(_KVer $n)) -> $(_KPath $n)" }
    { $_ -in 'list', 'ls', 'env' } {
      '{0,-20} {1,-10} {2}' -f 'NAME', 'PYTHON', 'PATH'
      Get-ChildItem -Directory (_KEnvs) | ForEach-Object {
        try { $ver = _KVer $_.Name } catch { return }
        $m = if ($env:VIRTUAL_ENV -eq $_.FullName) { '*' } else { ' ' }
        '{0,-20} {1,-10} {2}' -f ($m + $_.Name), $ver, $_.FullName } }
    'activate' {
      $p = _KPath $rest[0]; $null = _KPy $rest[0]
      if ($env:VIRTUAL_ENV -and (Get-Command deactivate -ErrorAction SilentlyContinue)) { deactivate }
      $a = @((Join-Path $p 'Scripts\activate.ps1'), (Join-Path $p 'bin/activate.ps1')) | Where-Object { Test-Path $_ } | Select-Object -First 1
      . $a }
    'deactivate' { if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate } }
    { $_ -in 'install', 'add' } { $t = _KTarget $name; _KUv pip install --python (_KPy $t) @rest }
    'uninstall' { $t = _KTarget $name; _KUv pip uninstall --python (_KPy $t) @rest }
    'freeze' { $t = _KTarget $name; _KUv pip freeze -q --python (_KPy $t) }
    'export' {
      $t = _KTarget $name; $out = $null; $lock = $false
      for ($i = 0; $i -lt $rest.Count; $i++) { if ($rest[$i] -eq '-o') { $out = $rest[++$i] } elseif ($rest[$i] -eq '--lock') { $lock = $true } }
      $ver = _KVer $t; $lines = @("# kenv-env: $t", "# python: $ver")
      $frz = & uv pip freeze -q --python (_KPy $t)
      if ($lock) {
        $tmp = [IO.Path]::GetTempFileName(); Set-Content $tmp $frz
        $lines += & uv pip compile -q $tmp --python-version ($ver -replace '\.\d+$', '') --generate-hashes --no-header
        Remove-Item $tmp
      } else { $lines += $frz }
      if ($out) { Set-Content -Encoding utf8 $out $lines; "exported '$t' -> $out" } else { $lines } }
    'import' {
      $n = $rest[0]; $f = $rest[1]
      $v = (Select-String -Path $f -Pattern '^# python: (.+)$' | Select-Object -First 1).Matches.Groups[1].Value
      if ($rest[2] -eq '--python') { $v = $rest[3] }; if (-not $v) { $v = '3.12' }
      _KMk $n $v; _KUv pip sync -q --python (_KPy $n) $f
      "imported '$n' (Python $(_KVer $n)) from $f" }
    'clone' {
      $s, $d = $rest[0], $rest[1]; $tmp = [IO.Path]::GetTempFileName()
      Set-Content $tmp (& uv pip freeze -q --python (_KPy $s))
      _KMk $d (_KVer $s); _KUv pip sync -q --python (_KPy $d) $tmp; Remove-Item $tmp
      "cloned '$s' -> '$d'" }
    'kernel' {
      $t = _KTarget $name; $py = _KPy $t
      _KUv pip install -q --python $py ipykernel
      & $py -m ipykernel install --user --name "kenv-$t" --display-name "Python $(_KVer $t) (kenv: $t)" }
    'audit' {
      $t = _KTarget $name; $tmp = [IO.Path]::GetTempFileName()
      Set-Content $tmp (& uv pip freeze -q --python (_KPy $t))
      & uvx -q pip-audit -r $tmp --no-deps --disable-pip --progress-spinner off; $rc = $LASTEXITCODE
      Remove-Item $tmp; $global:LASTEXITCODE = $rc }
    { $_ -in 'remove', 'rm' } {
      $p = _KPath $rest[0]; $null = _KPy $rest[0]
      if ($env:VIRTUAL_ENV -eq $p) { throw "kenv: deactivate first" }
      Remove-Item -Recurse -Force $p
      $k = _KKernelDir $rest[0]; if (Test-Path $k) { Remove-Item -Recurse -Force $k }
      "removed '$($rest[0])'" }
    'python' { _KUv python @rest }
    'prefix' { $null = _KPy $rest[0]; _KPath $rest[0] }
    default { _KUsage }
  }
}
Export-ModuleMember -Function kenv
