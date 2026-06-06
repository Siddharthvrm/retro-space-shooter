#!/usr/bin/env bash
set -uo pipefail

GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$GAME_DIR"
export TERM="${TERM:-xterm-256color}"

source "src/config.sh"
source "src/input.sh"
source "src/render.sh"
source "src/explosion.sh"

SCREEN_W=0
SCREEN_H=0
PLAY_H=0
LAST_SCREEN_W=0
LAST_SCREEN_H=0

player_x=1
player_y=1
player_hp=$PLAYER_HP_MAX
fire_cooldown=0
move_hold_dir=0
move_hold_frames=0
fire_hold_frames=0

score=0
high_score=0
wave=1
wave_kills=0
wave_target=8
frame=0
running=1
paused=0
game_over=0
status_text="READY"

bullets_x=()
bullets_y=()
enemy_bullets_x=()
enemy_bullets_y=()
enemy_bullets_tick=()
enemies_x=()
enemies_y=()
enemies_hp=()
enemies_type=()
enemies_tick=()
stars_x=()
stars_y=()
explosions_x=()
explosions_y=()
explosions_frame=()

player_sprite=$'    /^^\\\n __/====\\__\n|___====___|\n   /_||_\\'
player_w=12
player_h=4

scout_sprite=$' .--. \n (oo) \n \'--\' '
fighter_sprite=$' \\||/\n<====>\n /||\\'
heavy_sprite=$' /MMMM\\\n|MMMMMM|\n \\MMMM/\n  \\/\\/'
boss_sprite=$'   .-========-.\n _/  X    X   \\_\n|      /\\       |\n|   \\______/    |\n \\____________/'

ensure_data() {
  mkdir -p "$DATA_DIR"
  [[ -f "$HIGH_SCORE_FILE" ]] || printf '0\n' > "$HIGH_SCORE_FILE"
  high_score="$(tr -dc '0-9' < "$HIGH_SCORE_FILE" | head -c 12)"
  high_score="${high_score:-0}"
}

save_high_score() {
  if (( score > high_score )); then
    high_score="$score"
    printf '%s\n' "$high_score" > "$HIGH_SCORE_FILE"
  fi
}

refresh_size() {
  SCREEN_W="$(tput cols 2>/dev/null || true)"
  SCREEN_H="$(tput lines 2>/dev/null || true)"

  if [[ ! "$SCREEN_W" =~ ^[0-9]+$ || ! "$SCREEN_H" =~ ^[0-9]+$ || "$SCREEN_W" -eq 0 || "$SCREEN_H" -eq 0 ]]; then
    local stty_size rows cols
    stty_size="$(stty size 2>/dev/null || true)"
    rows="${stty_size%% *}"
    cols="${stty_size##* }"

    if [[ "$rows" =~ ^[0-9]+$ && "$cols" =~ ^[0-9]+$ && "$rows" -gt 0 && "$cols" -gt 0 ]]; then
      SCREEN_W="$cols"
      SCREEN_H="$rows"
    fi
  fi

  [[ "$SCREEN_W" =~ ^[0-9]+$ && "$SCREEN_W" -gt 0 ]] || SCREEN_W="${COLUMNS:-80}"
  [[ "$SCREEN_H" =~ ^[0-9]+$ && "$SCREEN_H" -gt 0 ]] || SCREEN_H="${LINES:-24}"
  PLAY_H=$((SCREEN_H - HUD_LINES))
}

clamp_to_screen() {
  local i type width height

  (( PLAY_H < 1 )) && PLAY_H=1
  player_y=$((PLAY_H - player_h))
  (( player_y < 1 )) && player_y=1
  (( player_x < 1 )) && player_x=1
  (( player_x > SCREEN_W - player_w + 1 )) && player_x=$((SCREEN_W - player_w + 1))
  (( player_x < 1 )) && player_x=1

  for ((i = 0; i < ${#stars_x[@]}; i++)); do
    (( stars_x[i] < 1 || stars_x[i] > SCREEN_W )) && stars_x[i]=$((RANDOM % SCREEN_W + 1))
    (( stars_y[i] < 1 || stars_y[i] > PLAY_H )) && stars_y[i]=$((RANDOM % PLAY_H + 1))
  done

  i=0
  while (( i < ${#bullets_x[@]} )); do
    if (( bullets_x[i] < 1 || bullets_x[i] > SCREEN_W || bullets_y[i] < 1 || bullets_y[i] > PLAY_H )); then
      remove_bullet "$i"
    else
      i=$((i + 1))
    fi
  done

  i=0
  while (( i < ${#enemy_bullets_x[@]} )); do
    if (( enemy_bullets_x[i] < 1 || enemy_bullets_x[i] > SCREEN_W || enemy_bullets_y[i] < 1 || enemy_bullets_y[i] > PLAY_H )); then
      remove_enemy_bullet "$i"
    else
      i=$((i + 1))
    fi
  done

  i=0
  while (( i < ${#enemies_x[@]} )); do
    type="${enemies_type[i]}"
    width="$(enemy_width "$type")"
    height="$(enemy_height "$type")"

    if (( enemies_y[i] > PLAY_H )); then
      remove_enemy "$i"
      continue
    fi

    (( enemies_x[i] < 1 )) && enemies_x[i]=1
    (( enemies_x[i] > SCREEN_W - width + 1 )) && enemies_x[i]=$((SCREEN_W - width + 1))
    (( enemies_x[i] < 1 )) && enemies_x[i]=1
    (( enemies_y[i] + height - 1 > PLAY_H )) && enemies_y[i]=$((PLAY_H - height + 1))
    (( enemies_y[i] < 1 )) && enemies_y[i]=1
    i=$((i + 1))
  done

  for ((i = 0; i < ${#explosions_x[@]}; i++)); do
    (( explosions_x[i] < 1 )) && explosions_x[i]=1
    (( explosions_x[i] > SCREEN_W )) && explosions_x[i]=SCREEN_W
    (( explosions_y[i] < 1 )) && explosions_y[i]=1
    (( explosions_y[i] > PLAY_H )) && explosions_y[i]=PLAY_H
  done
}

sync_screen_size() {
  refresh_size
  if (( SCREEN_W != LAST_SCREEN_W || SCREEN_H != LAST_SCREEN_H )); then
    printf '\033[2J'
    LAST_SCREEN_W="$SCREEN_W"
    LAST_SCREEN_H="$SCREEN_H"
  fi
  clamp_to_screen
}

require_size() {
  refresh_size
  if (( SCREEN_W < MIN_WIDTH || SCREEN_H < MIN_HEIGHT )); then
    printf 'RETRO SPACE SHOOTER needs at least %dx%d terminal size.\n' "$MIN_WIDTH" "$MIN_HEIGHT"
    printf 'Current size is %dx%d. Resize and run again.\n' "$SCREEN_W" "$SCREEN_H"
    exit 1
  fi
}

title_screen() {
  require_size
  printf '\033[2J\033[H'
  draw_at 1 2 "RETRO SPACE SHOOTER"
  draw_at 1 4 "HIGH SCORE $(printf '%06d' "$high_score")"
  draw_at 1 6 "A/D MOVE   SPACE FIRE   P PAUSE   Q QUIT"
  draw_at 1 8 "Press SPACE to launch."

  local key=""
  while true; do
    IFS= read -rsn1 key || true
    case "$key" in
      " ") break ;;
      q|Q) exit 0 ;;
    esac
  done
}

init_game() {
  local i
  sync_screen_size
  player_x=$((SCREEN_W / 2 - player_w / 2))
  player_y=$((PLAY_H - player_h))
  LAST_SCREEN_W="$SCREEN_W"
  LAST_SCREEN_H="$SCREEN_H"

  stars_x=()
  stars_y=()
  for ((i = 0; i < STAR_COUNT; i++)); do
    stars_x+=( $((RANDOM % SCREEN_W + 1)) )
    stars_y+=( $((RANDOM % PLAY_H + 1)) )
  done
}

enemy_width() {
  case "$1" in
    scout) printf '6' ;;
    fighter) printf '6' ;;
    heavy) printf '8' ;;
    boss) printf '17' ;;
  esac
}

enemy_height() {
  case "$1" in
    scout) printf '3' ;;
    fighter) printf '3' ;;
    heavy) printf '4' ;;
    boss) printf '5' ;;
  esac
}

enemy_points() {
  case "$1" in
    scout) printf '10' ;;
    fighter) printf '20' ;;
    heavy) printf '50' ;;
    boss) printf '500' ;;
  esac
}

enemy_sprite() {
  case "$1" in
    scout) printf '%s' "$scout_sprite" ;;
    fighter) printf '%s' "$fighter_sprite" ;;
    heavy) printf '%s' "$heavy_sprite" ;;
    boss) printf '%s' "$boss_sprite" ;;
  esac
}

enemy_speed_delay() {
  local type="$1"
  local base

  case "$type" in
    scout) base=7 ;;
    fighter) base=10 ;;
    heavy) base=14 ;;
    boss) base=6 ;;
  esac

  base=$((base - wave / 3))
  (( base < 2 )) && base=2
  printf '%s' "$base"
}

spawn_enemy() {
  local type="$1"
  local hp="$2"
  local width spawn_range
  width="$(enemy_width "$type")"
  spawn_range=$((SCREEN_W - width + 1))
  (( spawn_range < 1 )) && spawn_range=1

  enemies_type+=( "$type" )
  enemies_hp+=( "$hp" )
  enemies_x+=( $((RANDOM % spawn_range + 1)) )
  enemies_y+=( 1 )
  enemies_tick+=( 0 )
}

spawn_wave_enemy() {
  if (( wave % 5 == 0 && wave_kills == 0 && ${#enemies_x[@]} == 0 )); then
    spawn_enemy boss $((18 + wave * 3))
    status_text="BOSS"
    return
  fi

  local roll=$((RANDOM % 100))
  if (( roll < 55 )); then
    spawn_enemy scout 1
  elif (( roll < 85 )); then
    spawn_enemy fighter 2
  else
    spawn_enemy heavy 3
  fi
}

fire_bullet() {
  if (( fire_cooldown == 0 )); then
    bullets_x+=( $((player_x + player_w / 2)) )
    bullets_y+=( $((player_y - 1)) )
    fire_cooldown=$PLAYER_FIRE_COOLDOWN
  fi
}

handle_input() {
  read_input
  local i key

  for ((i = 0; i < ${#INPUT_KEYS}; i++)); do
    key="${INPUT_KEYS:i:1}"
    case "$key" in
      a|A)
        move_hold_dir=-1
        move_hold_frames=$PLAYER_MOVE_HOLD_FRAMES
        ;;
      d|D)
        move_hold_dir=1
        move_hold_frames=$PLAYER_MOVE_HOLD_FRAMES
        ;;
      " ")
        fire_hold_frames=$PLAYER_FIRE_HOLD_FRAMES
        ;;
      p|P)
        paused=$((1 - paused))
        if (( paused )); then status_text="PAUSED"; else status_text="FIGHT"; fi
        ;;
      q|Q)
        running=0
        ;;
    esac
  done

  if (( move_hold_frames > 0 )); then
    player_x=$((player_x + move_hold_dir * PLAYER_SPEED))
    move_hold_frames=$((move_hold_frames - 1))
  else
    move_hold_dir=0
  fi

  (( player_x < 1 )) && player_x=1
  (( player_x > SCREEN_W - player_w + 1 )) && player_x=$((SCREEN_W - player_w + 1))
  (( player_x < 1 )) && player_x=1

  if (( fire_hold_frames > 0 )); then
    fire_bullet
    fire_hold_frames=$((fire_hold_frames - 1))
  fi
}

remove_bullet() {
  local i="$1"
  unset 'bullets_x[i]' 'bullets_y[i]'
  bullets_x=( "${bullets_x[@]}" )
  bullets_y=( "${bullets_y[@]}" )
}

remove_enemy_bullet() {
  local i="$1"
  unset 'enemy_bullets_x[i]' 'enemy_bullets_y[i]' 'enemy_bullets_tick[i]'
  enemy_bullets_x=( "${enemy_bullets_x[@]}" )
  enemy_bullets_y=( "${enemy_bullets_y[@]}" )
  enemy_bullets_tick=( "${enemy_bullets_tick[@]}" )
}

remove_enemy() {
  local i="$1"
  unset 'enemies_x[i]' 'enemies_y[i]' 'enemies_hp[i]' 'enemies_type[i]' 'enemies_tick[i]'
  enemies_x=( "${enemies_x[@]}" )
  enemies_y=( "${enemies_y[@]}" )
  enemies_hp=( "${enemies_hp[@]}" )
  enemies_type=( "${enemies_type[@]}" )
  enemies_tick=( "${enemies_tick[@]}" )
}

add_explosion() {
  explosions_x+=( "$1" )
  explosions_y+=( "$2" )
  explosions_frame+=( 0 )
}

damage_player() {
  player_hp=$((player_hp - 1))
  status_text="HIT"
  if (( player_hp <= 0 )); then
    player_hp=0
    game_over=1
    running=0
  fi
}

enemy_fire_interval() {
  local interval=$((ENEMY_BULLET_DELAY_BASE - wave * 2))
  (( interval < 6 )) && interval=6
  printf '%s' "$interval"
}

add_enemy_bullet() {
  enemy_bullets_x+=( "$1" )
  enemy_bullets_y+=( "$2" )
  enemy_bullets_tick+=( 0 )
}

advance_wave_if_needed() {
  if (( wave % 5 == 0 )); then
    if (( wave_kills >= 1 && ${#enemies_x[@]} == 0 )); then
      wave=$((wave + 1))
      wave_kills=0
      wave_target=$((8 + wave * 2))
      status_text="WAVE"
    fi
  elif (( wave_kills >= wave_target )); then
    wave=$((wave + 1))
    wave_kills=0
    wave_target=$((8 + wave * 2))
    status_text="WAVE"
  fi
}

update_stars() {
  local i
  for ((i = 0; i < ${#stars_x[@]}; i++)); do
    if (( frame % 3 == 0 )); then
      stars_y[i]=$((stars_y[i] + 1))
      if (( stars_y[i] > PLAY_H )); then
        stars_y[i]=1
        stars_x[i]=$((RANDOM % SCREEN_W + 1))
      fi
    fi
  done
}

update_bullets() {
  local i=0
  while (( i < ${#bullets_x[@]} )); do
    bullets_y[i]=$((bullets_y[i] - 1))
    if (( bullets_y[i] < 1 )); then
      remove_bullet "$i"
    else
      i=$((i + 1))
    fi
  done
}

update_enemy_fire() {
  (( wave < 2 )) && return

  local i type width height interval shot_roll
  interval="$(enemy_fire_interval)"

  for ((i = 0; i < ${#enemies_x[@]}; i++)); do
    type="${enemies_type[i]}"
    [[ "$type" == "heavy" || "$type" == "boss" ]] || continue
    (( frame % interval == 0 )) || continue

    shot_roll=$((RANDOM % 100))
    (( shot_roll < 55 + wave * 2 )) || continue

    width="$(enemy_width "$type")"
    height="$(enemy_height "$type")"
    add_enemy_bullet "$((enemies_x[i] + width / 2))" "$((enemies_y[i] + height))"
  done
}

update_enemy_bullets() {
  local i=0
  while (( i < ${#enemy_bullets_x[@]} )); do
    enemy_bullets_tick[i]=$((enemy_bullets_tick[i] + 1))
    if (( enemy_bullets_tick[i] >= ENEMY_BULLET_SPEED_DELAY )); then
      enemy_bullets_tick[i]=0
      enemy_bullets_y[i]=$((enemy_bullets_y[i] + 1))
    fi

    if (( enemy_bullets_y[i] > PLAY_H )); then
      remove_enemy_bullet "$i"
    else
      i=$((i + 1))
    fi
  done
}

update_enemies() {
  local i=0 type delay height
  while (( i < ${#enemies_x[@]} )); do
    type="${enemies_type[i]}"
    delay="$(enemy_speed_delay "$type")"
    enemies_tick[i]=$((enemies_tick[i] + 1))

    if (( enemies_tick[i] >= delay )); then
      enemies_tick[i]=0
      enemies_y[i]=$((enemies_y[i] + 1))
    fi

    height="$(enemy_height "$type")"
    if (( enemies_y[i] + height - 1 >= player_y )); then
      add_explosion "${enemies_x[i]}" "${enemies_y[i]}"
      remove_enemy "$i"
      damage_player
    else
      i=$((i + 1))
    fi
  done
}

update_explosions() {
  local i=0
  while (( i < ${#explosions_x[@]} )); do
    explosions_frame[i]=$((explosions_frame[i] + 1))
    if (( explosions_frame[i] > 8 )); then
      unset 'explosions_x[i]' 'explosions_y[i]' 'explosions_frame[i]'
      explosions_x=( "${explosions_x[@]}" )
      explosions_y=( "${explosions_y[@]}" )
      explosions_frame=( "${explosions_frame[@]}" )
    else
      i=$((i + 1))
    fi
  done
}

check_collisions() {
  local bi=0 ei type ex ey ew eh bx by

  while (( bi < ${#bullets_x[@]} )); do
    bx="${bullets_x[bi]}"
    by="${bullets_y[bi]}"
    ei=0
    local hit=0

    while (( ei < ${#enemies_x[@]} )); do
      type="${enemies_type[ei]}"
      ex="${enemies_x[ei]}"
      ey="${enemies_y[ei]}"
      ew="$(enemy_width "$type")"
      eh="$(enemy_height "$type")"

      if (( bx >= ex && bx <= ex + ew - 1 && by >= ey && by <= ey + eh - 1 )); then
        enemies_hp[ei]=$((enemies_hp[ei] - 1))
        remove_bullet "$bi"
        hit=1

        if (( enemies_hp[ei] <= 0 )); then
          score=$((score + $(enemy_points "$type")))
          add_explosion "$ex" "$ey"
          remove_enemy "$ei"
          wave_kills=$((wave_kills + 1))
          status_text="BOOM"
        fi
        break
      fi
      ei=$((ei + 1))
    done

    (( hit == 0 )) && bi=$((bi + 1))
  done
}

check_enemy_bullet_collisions() {
  local i=0 bx by
  while (( i < ${#enemy_bullets_x[@]} )); do
    bx="${enemy_bullets_x[i]}"
    by="${enemy_bullets_y[i]}"

    if (( bx >= player_x && bx <= player_x + player_w - 1 && by >= player_y && by <= player_y + player_h - 1 )); then
      add_explosion "$bx" "$by"
      remove_enemy_bullet "$i"
      damage_player
    else
      i=$((i + 1))
    fi
  done
}

maybe_spawn() {
  local interval=$((24 - wave))
  (( interval < 7 )) && interval=7

  if (( ${#enemies_x[@]} < 5 + wave / 2 && frame % interval == 0 )); then
    spawn_wave_enemy
  fi
}

update_world() {
  sync_screen_size
  (( fire_cooldown > 0 )) && fire_cooldown=$((fire_cooldown - 1))
  update_stars
  update_bullets
  update_enemy_bullets
  maybe_spawn
  update_enemies
  update_enemy_fire
  check_collisions
  check_enemy_bullet_collisions
  update_explosions
  advance_wave_if_needed
  frame=$((frame + 1))
}

render_world() {
  local i type sprite

  sync_screen_size
  clear_frame
  blank_screen_buffer

  for ((i = 0; i < ${#stars_x[@]}; i++)); do
    draw_at "${stars_x[i]}" "${stars_y[i]}" "."
  done

  for ((i = 0; i < ${#bullets_x[@]}; i++)); do
    draw_at "${bullets_x[i]}" "${bullets_y[i]}" "|"
  done

  for ((i = 0; i < ${#enemy_bullets_x[@]}; i++)); do
    draw_at "${enemy_bullets_x[i]}" "${enemy_bullets_y[i]}" "!"
  done

  for ((i = 0; i < ${#enemies_x[@]}; i++)); do
    type="${enemies_type[i]}"
    sprite="$(enemy_sprite "$type")"
    draw_multiline_at "${enemies_x[i]}" "${enemies_y[i]}" "$sprite"
  done

  for ((i = 0; i < ${#explosions_x[@]}; i++)); do
    sprite="$(explosion_sprite $((explosions_frame[i] / 3)))"
    draw_multiline_at "${explosions_x[i]}" "${explosions_y[i]}" "$sprite"
  done

  draw_multiline_at "$player_x" "$player_y" "$player_sprite"
  render_hud
}

game_loop() {
  setup_terminal
  trap 'save_high_score; restore_terminal; exit 130' INT TERM
  trap 'save_high_score; restore_terminal' EXIT

  status_text="FIGHT"
  while (( running )); do
    handle_input
    if (( paused == 0 )); then
      update_world
    fi
    render_world
    sleep "$FRAME_DELAY"
  done
  trap - EXIT INT TERM
}

game_over_screen() {
  save_high_score
  printf '\033[2J\033[H'
  draw_at 1 2 "GAME OVER"
  draw_at 1 4 "$(printf 'SCORE %06d' "$score")"
  draw_at 1 5 "$(printf 'HIGH  %06d' "$high_score")"
  draw_at 7 7 "Thanks for playing."
  printf '\033[%d;1H' "$SCREEN_H"
}

main() {
  ensure_data
  require_size
  title_screen
  init_game
  game_loop
  restore_terminal

  if (( game_over )); then
    game_over_screen
  else
    save_high_score
    printf '\033[2J\033[H'
    printf 'RETRO SPACE SHOOTER closed. Score: %06d\n' "$score"
  fi
}

main "$@"
