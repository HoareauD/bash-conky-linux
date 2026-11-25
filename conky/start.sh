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
mkdir -p "$base/runtime"
exec 9>"${XDG_RUNTIME_DIR:-$base}/conky-supervision.lock"
flock -n 9 || exit 0
pids=()
stop_panels() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || :; done
  for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || :; done
  pids=()
}
trap 'stop_panels; exit 0' TERM INT HUP
trap stop_panels EXIT
last=''
while :; do
  monitors=$(xrandr --listmonitors 2>/dev/null) || { sleep 5; continue; }
  mapfile -t ids < <(printf '%s\n' "$monitors" | awk '$1 ~ /^[0-9]+:$/ {sub(/:$/, "", $1); print $1}')
  ((${#ids[@]})) || { sleep 5; continue; }
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
    for id in "${ids[@]}"; do
      "$conky_bin" -c "$base/runtime/conky.conf" -m "$id" 9>&- >>"$base/runtime/conky.log" 2>&1 &
      pids+=("$!")
    done
    last="$signature"
  fi
  sleep 5
done
