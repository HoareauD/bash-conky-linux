#!/usr/bin/env bash
for d in /sys/class/power_supply/*; do
  [[ -r "$d/type" && $(cat "$d/type") == Battery && -r "$d/capacity" ]] || continue
  status=$(cat "$d/status" 2>/dev/null)
  case "$status" in Charging) status='En charge';; Discharging) status='Sur batterie';; Full) status='Chargée';; 'Not charging') status='Pas en charge';; *) status='État inconnu';; esac
  printf '%s %% — %s\n' "$(cat "$d/capacity")" "$status"
done
