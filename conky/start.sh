#!/usr/bin/env bash
set -u
if locale -a 2>/dev/null | grep -Eiq '^fr_FR\.utf-?8$'; then
  export LC_ALL=fr_FR.UTF-8
fi
conky_bin=$(command -v conky) || conky_bin="$HOME/.local/bin/conky"
if [[ ! -x "$conky_bin" ]]; then
  printf '%s\n' 'Conky est introuvable. Installe-le avant de lancer la supervision.' >&2
  exit 1
fi
if ! command -v xrandr >/dev/null 2>&1; then
  printf '%s\n' 'La commande xrandr est requise pour détecter les écrans.' >&2
  exit 1
fi
base="$HOME/.config/conky"
if ! command -v wmctrl >/dev/null 2>&1; then
  printf '%s\n' 'La commande wmctrl est requise pour positionner les panneaux Conky.' >&2
  exit 1
fi
mkdir -p "$base/runtime"
exec 9>"${XDG_RUNTIME_DIR:-$base}/conky-supervision.lock"
flock -n 9 || exit 0
pids=()
stop_panels() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || :; done
  for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || :; done
  pids=()
}
place_panel() {
  local pid=$1 left=$2 top=$3 screen_width=$4
  local window width x y attempt
  for ((attempt=0; attempt<25; attempt++)); do
    kill -0 "$pid" 2>/dev/null || return 1
    if read -r window width < <(LC_ALL=C wmctrl -lpG 2>/dev/null |
      awk -v pid="$pid" '$3 == pid && $6 > 0 {print $1, $6; exit}'); then
      x=$((left + screen_width - width - 25))
      if ((x < left)); then x=$left; fi
      y=$((top + 50))
      if wmctrl -i -r "$window" -e "0,$x,$y,-1,-1"; then
        return 0
      fi
    fi
    sleep 0.2
  done
  printf 'Impossible de placer la fenêtre Conky du processus %s.\n' "$pid" >&2
  return 1
}

trap 'stop_panels; exit 0' TERM INT HUP
trap stop_panels EXIT
last=''
while :; do
  monitors=$(xrandr --listmonitors 2>/dev/null) || { sleep 5; continue; }
  mapfile -t screens < <(
    while read -r id _ geometry _; do
      [[ "$id" =~ ^[0-9]+:$ ]] || continue
      if [[ "$geometry" =~ ^([0-9]+)/[0-9]+x[0-9]+/[0-9]+([+-][0-9]+)([+-][0-9]+)$ ]]; then
        printf '%s %s %s %s\n' "${id%:}" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
      fi
    done <<< "$monitors"
  )
  ((${#screens[@]})) || { sleep 5; continue; }
  net=$(ip -4 route show default | awk '{for(i=1;i<NF;i++) if($i=="dev" && $(i+1)!~/^(wg|tun|tailscale)/){print $(i+1); exit}}')
  [[ -n "$net" ]] || net=$(ip -6 route show default | awk '{for(i=1;i<NF;i++) if($i=="dev"){print $(i+1); exit}}')
  [[ "$net" =~ ^[a-zA-Z0-9_.:-]+$ ]] || net=lo
  battery=''
  if [[ -n $(bash "$base/battery.sh") ]]; then
    battery='${color1}BATTERIE ${hr 1}${color}\n${execi 15 bash ~/.config/conky/battery.sh}'
  fi
  signature="$monitors|$net|$battery"
  dead=0
  for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null || dead=1; done
  if [[ "$signature" != "$last" || $dead == 1 ]]; then
    stop_panels
    sed -e "s/@NET@/$net/g" -e "s|@BATTERY@|$battery|" "$base/conky.conf" > "$base/runtime/conky.conf"
    printf '%s\n' "$monitors" > "$base/runtime/moniteurs.txt"
    for screen in "${screens[@]}"; do
      read -r id screen_width left top <<< "$screen"
      "$conky_bin" -c "$base/runtime/conky.conf" -m "$id" 9>&- >>"$base/runtime/conky.log" 2>&1 &
      pid=$!
      pids+=("$pid")
      place_panel "$pid" "$left" "$top" "$screen_width" >>"$base/runtime/conky.log" 2>&1 || :
    done
    last="$signature"
  fi
  sleep 5
done
