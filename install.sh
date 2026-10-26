#!/usr/bin/env bash
# kenv installer (Linux/macOS)
#   ./install.sh            user install  -> ~/.local/share/kenv, envs in ~/.kenv/envs
#   sudo ./install.sh --system [--group kenv]
#                           system install -> /opt/kenv, shared envs in /opt/kenv/envs,
#                           shared Python builds in /opt/kenv/python, /etc/profile.d/kenv.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"; MODE=user; GROUP=kenv
while [[ $# -gt 0 ]]; do case "$1" in --system) MODE=system; shift;; --group) GROUP="$2"; shift 2;; *) echo "unknown: $1"; exit 1;; esac; done
if [[ $MODE == system ]]; then
  [[ $EUID -eq 0 ]] || { echo "--system needs root (sudo)"; exit 1; }
  DEST=/opt/kenv
  if ! command -v uv >/dev/null; then curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh; fi
  getent group "$GROUP" >/dev/null || groupadd "$GROUP"
  mkdir -p $DEST/bin $DEST/envs $DEST/python
  install -m755 "$SRC/bin/kenv" $DEST/bin/kenv; install -m644 "$SRC/kenv.sh" $DEST/kenv.sh
  chgrp -R "$GROUP" $DEST/envs $DEST/python; chmod 2775 $DEST/envs $DEST/python
  cat > /etc/profile.d/kenv.sh <<P
export KENV_HOME=$DEST
export UV_PYTHON_INSTALL_DIR=$DEST/python
umask 002
[ -n "\${BASH_VERSION:-}\${ZSH_VERSION:-}" ] && . $DEST/kenv.sh
P
  echo "system install done. Add users: usermod -aG $GROUP <user>; re-login."
else
  DEST="${XDG_DATA_HOME:-$HOME/.local/share}/kenv"
  if ! command -v uv >/dev/null && [[ ! -x $HOME/.local/bin/uv ]]; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  mkdir -p "$DEST/bin" "$HOME/.kenv/envs"
  install -m755 "$SRC/bin/kenv" "$DEST/bin/kenv"; install -m644 "$SRC/kenv.sh" "$DEST/kenv.sh"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ $rc == *zshrc && ! -f $rc ]] && continue
    grep -qF "$DEST/kenv.sh" "$rc" 2>/dev/null || printf '\nexport PATH="$HOME/.local/bin:$PATH"\nsource "%s"\n' "$DEST/kenv.sh" >> "$rc"
  done
  echo "user install done -> $DEST. Run: source ~/.bashrc && kenv list"
fi
