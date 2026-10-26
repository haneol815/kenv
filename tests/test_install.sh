#!/usr/bin/env bash
# install.sh in a clean HOME: install, idempotent reinstall, uninstall, reinstall
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT
touch "$H/.bashrc"
run(){ env -i HOME="$H" PATH="$(dirname "$(command -v uv)"):/usr/local/bin:/usr/bin:/bin" TERM=dumb bash -c "$1"; }
run "cd '$ROOT' && ./install.sh && ./install.sh"
[[ $(grep -c '# >>> kenv >>>' "$H/.bashrc") == 1 ]] || { echo "FAIL duplicate rc block"; exit 1; }
run 'source ~/.bashrc && kenv create t --python 3.12 six && kenv activate t && python -c "import six" && kenv deactivate && ~/.local/bin/kenv list | grep " t " >/dev/null && kenv remove t'
run "cd '$ROOT' && ./install.sh --uninstall"
[[ ! -e $H/.local/share/kenv && ! -e $H/.local/bin/kenv ]] || { echo "FAIL uninstall left files"; exit 1; }
! grep -q kenv "$H/.bashrc" || { echo "FAIL rc not cleaned"; exit 1; }
run "cd '$ROOT' && ./install.sh" && run 'source ~/.bashrc && kenv list >/dev/null'
echo "install tests passed"
