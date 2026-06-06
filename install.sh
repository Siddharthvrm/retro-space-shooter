#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$ROOT_DIR/retro-space-shooter.sh"

mkdir -p "$ROOT_DIR/data"
if [[ ! -f "$ROOT_DIR/data/highscore.dat" ]]; then
  printf '0\n' > "$ROOT_DIR/data/highscore.dat"
fi

printf 'Installed RETRO SPACE SHOOTER.\n'
printf 'Run it with: %s/retro-space-shooter.sh\n' "$ROOT_DIR"
