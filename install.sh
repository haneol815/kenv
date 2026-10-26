#!/usr/bin/env bash
# kenv installer (Linux/macOS)
#   ./install.sh                     user install  -> ~/.local/share/kenv, envs in ~/.kenv/envs
#   ./install.sh --uninstall         remove user install (envs are kept)
#   sudo ./install.sh --system [--group kenv]   shared install -> /opt/kenv (envs + Python builds shared)
#   sudo ./install.sh --system --uninstall
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"; MODE=user; GROUP=kenv; UNINSTALL=0
while [[ $# -gt 0 ]]; do case "$1" in
  --system) MODE=system; shift;;
  --group) [[ $# -ge 2 ]] || { echo "--group needs a value" >&2; exit 1; }; GROUP="$2"; shift 2;;
  --uninstall) UNINSTALL=1; shift;;
  -h|--help) sed -n '2,6p' "$0"; exit 0;;
  *) echo "unknown option: $1" >&2; exit 1;; esac; done
[[ -f "$SRC/bin/kenv" && -f "$SRC/kenv.sh" ]] || { echo "run from the extracted kenv directory" >&2; exit 1; }
MARK="# >>> kenv >>>"; ENDM="# <<< kenv <<<"
strip_block(){ [[ -f "$1" ]] && sed -i -e "/^$MARK\$/,/^$ENDM\$/d" -e "\#^source \"$DEST/kenv.sh\"\$#d" "$1"; return 0; }

if [[ $MODE == system ]]; then
  [[ $EUID -eq 0 ]] || { echo "--system needs root (sudo)" >&2; exit 1; }
  DEST=/opt/kenv
  if [[ $UNINSTALL == 1 ]]; then
    rm -rf "${DEST:?}/bin" "${DEST:?}/kenv.sh" /etc/profile.d/kenv.sh /usr/local/bin/kenv
    echo "kenv system install removed (shared envs kept in $DEST/envs)"; exit 0; fi
  if ! command -v uv >/dev/null; then curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh; fi
  getent group "$GROUP" >/dev/null || groupadd "$GROUP"
  mkdir -p "$DEST/bin" "$DEST/envs" "$DEST/python"
  install -m755 "$SRC/bin/kenv" "$DEST/bin/kenv"; install -m644 "$SRC/kenv.sh" "$DEST/kenv.sh"
  ln -sf "$DEST/bin/kenv" /usr/local/bin/kenv
  chgrp "$GROUP" "$DEST/envs" "$DEST/python"; chmod 2775 "$DEST/envs" "$DEST/python"
  cat > /etc/profile.d/kenv.sh <<P
export KENV_HOME=$DEST
export UV_PYTHON_INSTALL_DIR=$DEST/python
# group-writable files only for members of the shared group
if id -nG 2>/dev/null | tr ' ' '\n' | grep -qx '$GROUP'; then umask 002; fi
if [ -n "\${BASH_VERSION:-}\${ZSH_VERSION:-}" ]; then . $DEST/kenv.sh; fi
P
  echo "system install done. Add users: usermod -aG $GROUP <user>; then re-login."
else
  DEST="${XDG_DATA_HOME:-$HOME/.local/share}/kenv"
  if [[ $UNINSTALL == 1 ]]; then
    rm -rf "$DEST"; rm -f "$HOME/.local/bin/kenv"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do strip_block "$rc"; done
    echo "kenv removed (envs kept in ${KENV_HOME:-$HOME/.kenv}/envs)"; exit 0; fi
  if ! command -v uv >/dev/null && [[ ! -x $HOME/.local/bin/uv ]]; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  mkdir -p "$DEST/bin" "$HOME/.kenv/envs" "$HOME/.local/bin"
  install -m755 "$SRC/bin/kenv" "$DEST/bin/kenv"; install -m644 "$SRC/kenv.sh" "$DEST/kenv.sh"
  ln -sf "$DEST/bin/kenv" "$HOME/.local/bin/kenv"   # for scripts / non-interactive shells
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ $rc == *zshrc && ! -f $rc ]] && continue
    strip_block "$rc"
    # shellcheck disable=SC2016
    printf '%s\nexport PATH="$HOME/.local/bin:$PATH"\nsource "%s"\n%s\n' "$MARK" "$DEST/kenv.sh" "$ENDM" >> "$rc"
  done
  echo "user install done -> $DEST. Run: source ~/.bashrc && kenv list"
fi
