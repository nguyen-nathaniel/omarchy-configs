#!/usr/bin/env bash
# Time-aware greeting + typewriter effect.
#
# Hyprlock runs cmd once per refresh and captures stdout when the process exits — it does not
# stream shell output. A blocking sleep-loop cannot animate the on-screen label; for hyprlock we
# use a session state file + elapsed time (see HYPRLOCK PATH). Run attached to a tty to use the
# real for-loop with \\r and clear-line sequences.
set -euo pipefail

# Milliseconds per revealed character (matches common cmd[update:100] refresh). Override: ARES_GREETING_STEP_MS=50
STEP_MS="${ARES_GREETING_STEP_MS:-100}"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE="${STATE_DIR}/ares-hyprlock-greeting.state"

SELF="${BASH_SOURCE[0]:-$0}"
SCRIPT_MT="$(stat -c %Y "${SELF}" 2>/dev/null || echo 0)"

user="${USER:-operator}"
hour=$((10#$(date +%H)))
minute=$((10#$(date +%M)))
slot=$((minute % 3))

if ((hour >= 5 && hour < 12)); then
  case $slot in
  0) FULL="welcome back, ${user}. good morning." ;;
  1) FULL="welcome back, ${user}. dawn cycle complete." ;;
  *) FULL="welcome back, ${user}. ready when you are." ;;
  esac
elif ((hour >= 12 && hour < 17)); then
  case $slot in
  0) FULL="welcome back, ${user}. afternoon watch." ;;
  1) FULL="welcome back, ${user}. uplink stable." ;;
  *) FULL="welcome back, ${user}. standing by." ;;
  esac
elif ((hour >= 17 && hour < 22)); then
  case $slot in
  0) FULL="evening cycle, ${user}. good evening." ;;
  1) FULL="welcome back, ${user}. good evening." ;;
  *) FULL="good evening, ${user}. are you ready to sign in?" ;;
  esac
else
  case $slot in
  0) FULL="quiet hours, ${user}. good night." ;;
  1) FULL="night cycle, ${user}. sleep imminent." ;;
  *) FULL="late shift, ${user}? ready when you are." ;;
  esac
fi

len=${#FULL}
if ((len == 0)); then
  echo ""
  exit 0
fi

sleep_chars() {
  awk -v ms="$STEP_MS" 'BEGIN { printf "%.4f", ms / 1000.0 }'
}

# --- TTY: real loop; carriage return + EL clear so one line; ends on full string + newline.
if [[ -t 1 ]]; then
  for ((i = 0; i <= len; i++)); do
    printf '\r\033[K%s' "${FULL:0:i}"
    sleep "$(sleep_chars)"
  done
  printf '\r\033[K%s\n' "${FULL}"
  exit 0
fi

# --- HYPRLOCK PATH: type once per state session, then hold full line (no idle 60s loop).
# Reset animation when the greeting text changes (hour/slot/variant). State is under
# XDG_RUNTIME_DIR (often cleared on logout).
if ! now_ns=$(date +%s%N 2>/dev/null) || [[ -z "${now_ns}" ]]; then
  echo "${FULL}"
  exit 0
fi

# Reset animation when: greeting text changed, or script was edited (mtime), or state is stale.
# Without a mtime check, changing only *other* hour/slot strings leaves the active line identical to
# line 2 in the state file — we then keep an old saved_start and elapsed_ms is huge → no typing.
need_reset=true
saved_start=""
if [[ -f "${STATE}" ]]; then
  saved_start=$(sed -n '1p' "${STATE}")
  saved_text=$(sed -n '2p' "${STATE}")
  saved_mt=$(sed -n '3p' "${STATE}")
  if [[ -n "${saved_start}" && "${saved_text}" == "${FULL}" && "${saved_mt}" == "${SCRIPT_MT}" ]]; then
    need_reset=false
  fi
fi

if ${need_reset}; then
  printf '%s\n%s\n%s\n' "${now_ns}" "${FULL}" "${SCRIPT_MT}" >"${STATE}"
  saved_start="${now_ns}"
fi

elapsed_ms=$(( (10#${now_ns} - 10#${saved_start}) / 1000000 ))
((elapsed_ms < 0)) && elapsed_ms=0

typing_ms=$((len * STEP_MS))
if ((elapsed_ms < typing_ms)); then
  n=$((elapsed_ms / STEP_MS))
  ((n > len)) && n=$len
  echo "${FULL:0:n}"
else
  echo "${FULL}"
fi
