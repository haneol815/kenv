# source this in ~/.bashrc / ~/.zshrc :  source /path/to/pyenv-manager/kenv.sh
_KENV_BIN="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/bin/kenv"
kenv() {
  case "$1" in
    activate)
      local p; p="$(command "$_KENV_BIN" prefix "$2")" || return 1
      [ -n "$VIRTUAL_ENV" ] && type deactivate >/dev/null 2>&1 && deactivate
      . "$p/bin/activate";;
    deactivate) type deactivate >/dev/null 2>&1 && deactivate;;
    *) command "$_KENV_BIN" "$@";;
  esac
}
