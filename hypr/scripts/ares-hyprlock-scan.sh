#!/usr/bin/env bash
# Idle: rotate first three lines. Typing: show passphrase line (requires hyprlock with $PASSDISPLAYLEN).
set -euo pipefail

idle_lines=(
  "> scanning local environment..."
  "> optimizing system stability..."
  "> initializing security protocols..."
  "> background processes nominal..."

)
passphrase_line="> analyzing passphrase..."

# Seconds between idle line changes (wall clock; cmd refresh interval is separate in hyprlock.conf).
period="${SCAN_ROTATE_SEC:-2}"

passlen="${1:-0}"
if [[ "${passlen}" =~ ^[0-9]+$ ]] && ((passlen > 0)); then
  echo "${passphrase_line}"
  exit 0
fi

idx=$(($(date +%s) / period % ${#idle_lines[@]}))
echo "${idle_lines[$idx]}"
