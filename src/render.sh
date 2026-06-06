#!/usr/bin/env bash

clear_frame() {
  printf '\033[H'
}

draw_at() {
  local x="$1"
  local y="$2"
  local text="$3"

  (( x < 1 || y < 1 || y > SCREEN_H )) && return
  printf '\033[%d;%dH%s' "$y" "$x" "$text"
}

draw_multiline_at() {
  local x="$1"
  local y="$2"
  local block="$3"
  local line
  local row=0

  while IFS= read -r line; do
    draw_at "$x" "$((y + row))" "$line"
    row=$((row + 1))
  done <<< "$block"
}

blank_screen_buffer() {
  local row
  for ((row = 1; row <= SCREEN_H; row++)); do
    printf '%*s' "$SCREEN_W" ''
    [[ "$row" -lt "$SCREEN_H" ]] && printf '\n'
  done
}

render_hud() {
  local hp_bar=""
  local i

  for ((i = 1; i <= PLAYER_HP_MAX; i++)); do
    if (( i <= player_hp )); then
      hp_bar="${hp_bar}#"
    else
      hp_bar="${hp_bar}-"
    fi
  done

  draw_at 1 "$((SCREEN_H - 2))" "$(printf 'HP [%s]' "$hp_bar")"
  draw_at 1 "$((SCREEN_H - 1))" "$(printf 'SCORE %06d   HIGH %06d' "$score" "$high_score")"
  draw_at 1 "$SCREEN_H" "$(printf 'WAVE %02d   %s' "$wave" "$status_text")"
}
