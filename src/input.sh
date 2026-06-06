#!/usr/bin/env bash

INPUT_KEY=""
INPUT_KEYS=""

setup_terminal() {
  OLD_STTY="$(stty -g)"
  stty -echo -icanon time 0 min 0
  printf '\033[?25l\033[2J'
}

restore_terminal() {
  stty "$OLD_STTY" 2>/dev/null || true
  printf '\033[?25h\033[0m\033[2J\033[H'
}

read_input() {
  INPUT_KEY=""
  INPUT_KEYS=""
  local key

  while IFS= read -rsn1 -t 0.001 key; do
    INPUT_KEY="$key"
    INPUT_KEYS="${INPUT_KEYS}${key}"
  done
}
