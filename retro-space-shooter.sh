#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export TERM="${TERM:-xterm-256color}"

exec bash "$SCRIPT_DIR/src/game.sh"
