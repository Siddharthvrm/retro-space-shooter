#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${RSS_REPO:-https://github.com/YOUR_USERNAME/retro-space-shooter.git}"
INSTALL_DIR="${RSS_DIR:-$HOME/.local/share/retro-space-shooter}"
BIN_DIR="${RSS_BIN_DIR:-$HOME/.local/bin}"
BIN_PATH="$BIN_DIR/retro-space-shooter"

command -v git >/dev/null 2>&1 || {
  printf 'git is required to install RETRO SPACE SHOOTER.\n' >&2
  exit 1
}

mkdir -p "$BIN_DIR" "$(dirname "$INSTALL_DIR")"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  git -C "$INSTALL_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

bash "$INSTALL_DIR/install.sh"
ln -sf "$INSTALL_DIR/retro-space-shooter.sh" "$BIN_PATH"

printf '\nInstalled RETRO SPACE SHOOTER.\n'
printf 'Run it with: %s\n' "$BIN_PATH"
printf 'If needed, add %s to your PATH.\n' "$BIN_DIR"
