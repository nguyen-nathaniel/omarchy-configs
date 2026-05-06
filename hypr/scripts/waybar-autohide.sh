#!/usr/bin/env bash
# Top-edge autohide for Waybar (Hyprland + Omarchy).
# Two vertical zones at the top of each monitor:
#   - Wake (enter): larger strip — cursor enters here to reveal waybar if hidden.
#   - Bar (exit): height from waybar config — cursor must leave this strip before hide
#     (after WAYBAR_AUTOHIDE_HIDE_DELAY_MS), so the bar does not dismiss while you move
#     through the larger wake region toward the bar.
# Uses omarchy-toggle-waybar so reserved space / tiling updates stay consistent.

set -uo pipefail

: "${WAYBAR_AUTOHIDE_POLL_MS:=80}"
: "${WAYBAR_AUTOHIDE_HIDE_DELAY_MS:=200}"
# Override parsed bar height (px). If unset, height is read from waybar config "height".
: "${WAYBAR_AUTOHIDE_BAR_HEIGHT:=}"
# Larger hit area (px) to reveal waybar. If unset, defaults to max(56, bar_height + 32).
: "${WAYBAR_AUTOHIDE_WAKE_HEIGHT:=2}"
# Default: $XDG_CONFIG_HOME/waybar/config.jsonc
: "${WAYBAR_AUTOHIDE_WAYBAR_CONFIG:=${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config.jsonc}"

if ! command -v jq >/dev/null 2>&1; then
  echo "waybar-autohide: jq is required" >&2
  exit 1
fi

resolve_bar_height_px() {
  local cfg="$WAYBAR_AUTOHIDE_WAYBAR_CONFIG"
  local h
  if [[ -n "${WAYBAR_AUTOHIDE_BAR_HEIGHT:-}" ]] && [[ "${WAYBAR_AUTOHIDE_BAR_HEIGHT}" =~ ^[0-9]+$ ]] && [[ "${WAYBAR_AUTOHIDE_BAR_HEIGHT}" -gt 0 ]]; then
    echo "${WAYBAR_AUTOHIDE_BAR_HEIGHT}"
    return 0
  fi
  if [[ -f "$cfg" ]]; then
    h=$(jq -r 'try (.height // 0) | tonumber' "$cfg" 2>/dev/null || echo 0)
    if [[ "$h" =~ ^[0-9]+$ ]] && [[ "$h" -gt 0 ]]; then
      echo "$h"
      return 0
    fi
    h=$(grep -oE '"height"[[:space:]]*:[[:space:]]*[0-9]+' "$cfg" | head -1 | grep -oE '[0-9]+$' || true)
    if [[ "$h" =~ ^[0-9]+$ ]] && [[ "$h" -gt 0 ]]; then
      echo "$h"
      return 0
    fi
  fi
  echo 32
}

bar_h=$(resolve_bar_height_px)

if [[ -n "${WAYBAR_AUTOHIDE_WAKE_HEIGHT:-}" ]] && [[ "${WAYBAR_AUTOHIDE_WAKE_HEIGHT}" =~ ^[0-9]+$ ]]; then
  wake_h="${WAYBAR_AUTOHIDE_WAKE_HEIGHT}"
else
  wake_h=$((bar_h + 32))
  if [[ "$wake_h" -lt 56 ]]; then
    wake_h=56
  fi
fi

runtime="${XDG_RUNTIME_DIR:-/tmp}"
mkdir -p "$runtime" 2>/dev/null || true
disable_file="$runtime/waybar-autohide.disabled"
lockfile="$runtime/waybar-autohide.lock"
exec 200>"$lockfile"
if ! flock -n 200; then
  exit 0
fi

sleep_secs=$(awk -v ms="$WAYBAR_AUTOHIDE_POLL_MS" 'BEGIN { printf "%.4f", ms/1000 }')
was_on_bar=false
was_in_wake=false
hide_deadline_ms=""

now_ms() {
  echo $(($(date +%s%3N)))
}

cursor_in_top_strip() {
  local mons_json="$1"
  local cx="$2"
  local cy="$3"
  local h="$4"
  echo "$mons_json" | jq -e --argjson cx "$cx" --argjson cy "$cy" --argjson hh "$h" '
    [.[] | select(
      ($cx | tonumber) >= .x and ($cx | tonumber) < (.x + .width) and
      ($cy | tonumber) >= .y and ($cy | tonumber) < (.y + $hh)
    )] | length > 0
  ' >/dev/null 2>&1
}

while true; do
  if [[ -f "$disable_file" ]]; then
    was_on_bar=false
    was_in_wake=false
    hide_deadline_ms=""
    sleep "$sleep_secs"
    continue
  fi

  read -r cx cy < <(hyprctl cursorpos -j 2>/dev/null | jq -r '[.x, .y] | @tsv') || true
  if [[ -z "${cx:-}" || -z "${cy:-}" ]]; then
    sleep "$sleep_secs"
    continue
  fi

  mons=$(hyprctl monitors -j 2>/dev/null) || {
    sleep "$sleep_secs"
    continue
  }

  if cursor_in_top_strip "$mons" "$cx" "$cy" "$bar_h"; then
    now_on_bar=true
  else
    now_on_bar=false
  fi

  if cursor_in_top_strip "$mons" "$cx" "$cy" "$wake_h"; then
    now_in_wake=true
  else
    now_in_wake=false
  fi

  if ! pgrep -x waybar >/dev/null; then
    hide_deadline_ms=""
    if [[ "$was_in_wake" == false && "$now_in_wake" == true ]]; then
      omarchy-toggle-waybar
    fi
  else
    if [[ "$now_on_bar" == true ]] || [[ "$was_in_wake" == false && "$now_in_wake" == true ]]; then
      hide_deadline_ms=""
    fi

    if [[ "$was_on_bar" == true && "$now_on_bar" == false ]] || [[ "$was_in_wake" == true && "$now_in_wake" == false ]]; then
      if [[ "$WAYBAR_AUTOHIDE_HIDE_DELAY_MS" -eq 0 ]]; then
        pgrep -x waybar >/dev/null && omarchy-toggle-waybar
      else
        hide_deadline_ms=$(( $(now_ms) + WAYBAR_AUTOHIDE_HIDE_DELAY_MS ))
      fi
    fi

    if [[ -n "$hide_deadline_ms" ]]; then
      if [[ "$(now_ms)" -ge "$hide_deadline_ms" ]]; then
        pgrep -x waybar >/dev/null && omarchy-toggle-waybar
        hide_deadline_ms=""
      fi
    fi
  fi

  was_on_bar=$now_on_bar
  was_in_wake=$now_in_wake
  sleep "$sleep_secs"
done
