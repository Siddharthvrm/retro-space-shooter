#!/usr/bin/env bash

explosion_sprite() {
  case "$1" in
    0) printf '  *\n *O*\n  *' ;;
    1) printf ' * * *\n*  O  *\n * * *' ;;
    *) printf '. . . .\n . . .' ;;
  esac
}
