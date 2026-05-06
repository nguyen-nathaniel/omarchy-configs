#!/usr/bin/env bash
# Toggle waybar top-edge autohide on/off (Hyprland bind helper).
# Uses a disable flag the daemon checks; when turning autohide off, shows waybar if it was hidden.
# Always restarts the autohide daemon so edits to waybar-autohide.sh (defaults/env) take effect.

set -uo pipefail

runtime="${XDG_RUNTIME_DIR:-/tmp}"
disable_file="$runtime/waybar-autohide.disabled"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
autohide_main="$script_dir/waybar-autohide.sh"

if [[ -f "$disable_file" ]]; then
  rm -f "$disable_file"
else
  touch "$disable_file"
  if ! pgrep -x waybar >/dev/null; then
    omarchy-toggle-waybar
  fi
fi

pkill -f -- "$autohide_main" 2>/dev/null || true
sleep 0.2
"$autohide_main" &
