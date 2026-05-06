#!/usr/bin/env bash
# Weather line for hyprlock via wttr.in (no API key). Fails soft on network errors.
set -euo pipefail

LOC="${HYPRLOCK_WEATHER_LOCATION:-}"
LOC_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock-weather-location"
if [[ -z "$LOC" && -f "$LOC_FILE" ]]; then
  LOC="$(head -n1 "$LOC_FILE" | tr -d '\r')"
fi

if [[ -n "$LOC" ]]; then
  URL="https://wttr.in/$(printf '%s' "$LOC" | sed 's/ /%20/g')?format=%C+%t+%h+%w"
else
  URL='https://wttr.in/?format=%C+%t+%h+%w'
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Weather: install curl"
  exit 0
fi

out="$(curl -fsS -m 4 -A 'hyprlock-weather' "$URL" 2>/dev/null || true)"
out="$(printf '%s' "$out" | tr -d '\r')"

if [[ -z "$out" ]]; then
  echo "Weather unavailable"
else
  printf '%s\n' "$out"
fi
