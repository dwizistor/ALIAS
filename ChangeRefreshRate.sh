#!/usr/bin/env bash

MON="eDP-1"
RES="1920x1080"
SCA=1

for dir in /run/user/*; do
  for hypr_dir in "$dir/hypr/"*/; do
    socket="${hypr_dir}.socket.sock"
    if [[ -S $socket ]]; then
      echo -e "keyword monitor $MON,$RES@$1,0x0,$SCA" | socat - UNIX-CONNECT:"$socket"
    fi
  done
done
