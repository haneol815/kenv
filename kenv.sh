# shellcheck shell=bash
# source this in ~/.bashrc / ~/.zshrc :  source /path/to/kenv/kenv.sh
_KENV_BIN="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/bin/kenv"
kenv() {
  case "${1:-}" in
    activate)
      local p; p="$(command "$_KENV_BIN" prefix "${2:-}")" || return 1
      if [ -n "${VIRTUAL_ENV:-}" ] && type deactivate >/dev/null 2>&1; then deactivate; fi
      # shellcheck disable=SC1091
      . "$p/bin/activate";;
    deactivate)
      if type deactivate >/dev/null 2>&1; then deactivate; else echo "kenv: no active env" >&2; return 1; fi;;
    *) command "$_KENV_BIN" "$@";;
  esac
}
