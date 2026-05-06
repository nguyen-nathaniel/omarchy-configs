#!/usr/bin/env bash
set -euo pipefail

STATE="/tmp/hyprlock-${UID}-cpu.state"
BAR_W=12

FULL="█"
EMPTY="░"

bar() {
  local pct=$1
  (( pct < 0 )) && printf "%*s" "$BAR_W" "" | tr ' ' "$EMPTY" && return
  (( pct > 100 )) && pct=100
  local filled=$(( pct * BAR_W / 100 ))
  printf "%*s" "$filled" "" | tr ' ' "$FULL"
  printf "%*s" "$((BAR_W - filled))" "" | tr ' ' "$EMPTY"
}

# ───────────────── CPU HEADER ─────────────────
read -r load1 load2 load3 _ < /proc/loadavg

printf "╭─ CPU ───────────────────────────────────────────────╮\n"
printf "│ Load avg: %-5s %-5s %-5s                         │\n" "$load1" "$load2" "$load3"

# ───────────────── CPU CORE PROCESSING ─────────────────
mapfile -t CPU_LINES < <(
awk -v SF="$STATE" '
BEGIN {
  while ((getline < SF) > 0) {
    pi[$1]=$2; pt[$1]=$3
  }
  close(SF)
}

/^cpu[0-9]+/ {
  name=$1
  idle=$5+$6
  total=0
  for(i=2;i<=NF;i++) total+=$i

  pct=-1
  if (name in pt) {
    dt = total - pt[name]
    di = idle - pi[name]
    if (dt>0) pct = int(100*(dt-di)/dt)
  }

  printf "%s %d %d\n", name, idle, total > SF".new"

  sub("cpu","C",name)

  if (pct < 0)
    printf "%-3s %s  ...\n", name, "░░░░░░░░░░░░"
  else {
    filled = int(pct * 12 / 100)
    bar=""
    for(i=0;i<12;i++) bar = bar (i<filled?"█":"░")
    printf "%-3s %s %3d%%\n", name, bar, pct
  }
}

END {
  system("mv "SF".new "SF" 2>/dev/null")
}
' /proc/stat
)

# ───────────────── SPLIT INTO 2 COLUMNS ─────────────────
total=${#CPU_LINES[@]}
half=$(( (total + 1) / 2 ))

for ((i=0; i<half; i++)); do
  left="${CPU_LINES[i]}"
  right=""
  if (( i + half < total )); then
    right="${CPU_LINES[i+half]}"
  fi

  printf "│ %-28s %-28s         │\n" "$left" "$right"
done

printf "╰─────────────────────────────────────────────────────╯\n"

# ───────────────── MEMORY ─────────────────
printf "\n╭─ MEMORY ────────────────────────────────────────────╮\n"

awk '
/MemTotal/ {t=$2}
/MemAvailable/ {a=$2}
/MemFree/ {f=$2}
/Cached/ {c=$2}
/SReclaimable/ {s=$2}

END {
  cache = c + s
  used = t - a
  tf = 1048576

  up = int(100*used/t)

  printf "│ Used:  %5.2fG (%3d%%) ", used/tf, up

  filled = int(up * 12 / 100)
  bar=""
  for(i=0;i<12;i++) bar = bar (i<filled?"█":"░")

  printf "%s                   │\n", bar
  printf "│ Available:  %5.2fG (%3d%%)                           │\n", a/tf, int(100*a/t)
  printf "│ Free: %5.2fG (%3d%%)                                 │\n", f/tf, int(100*f/t)
}
' /proc/meminfo

printf "╰─────────────────────────────────────────────────────╯\n"

# ───────────────── GPU ─────────────────
printf "\n╭─ GPU ───────────────────────────────────────────────╮\n"

if command -v nvidia-smi &>/dev/null; then
  IFS=',' read -r util temp power mem_used mem_total < <(
    nvidia-smi \
      --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.used,memory.total \
      --format=csv,noheader,nounits 2>/dev/null | head -n1
  )

  # Trim whitespace for all values (sometimes nvidia-smi pads values with a space after the comma)
  util=$(echo "$util" | xargs)
  temp=$(echo "$temp" | xargs)
  power=$(echo "$power" | xargs)
  mem_used=$(echo "$mem_used" | xargs)
  mem_total=$(echo "$mem_total" | xargs)

  pct=$util

  # power.draw is usually a decimal (e.g. 42.3 W); integer-only regex wrongly failed every time.
  if [[ "$pct" =~ ^[0-9]+$ && "$temp" =~ ^[0-9]+$ ]]; then
    if [[ "$power" =~ ^[0-9]+(\.[0-9]*)?$ ]]; then
      printf "│ Usage: %3d%%  Temp: %2d°C  Power: %6.1fW             │\n" "$pct" "$temp" "$power"
    else
      printf "│ Usage: %3d%%  Temp: %2d°C  Power:    -- W               │\n" "$pct" "$temp"
    fi
  else
    printf "│ Usage:  --%%  Temp:  --°C  Power:    -- W               │\n"
  fi

  # Fill bar using same awk-style as other sections
  filled=$(( pct * 12 / 100 ))
  bar=""
  for i in $(seq 0 11); do
    if (( i < filled )); then
      bar+="█"
    else
      bar+="░"
    fi
  done

  printf "│ %-48s                            │\n" "$bar"

  printf "│ VRAM: %4d / %4d MiB                               │\n" "$mem_used" "$mem_total"
  printf "╰─────────────────────────────────────────────────────╯\n"
else
  printf "│ No NVIDIA GPU detected                            │\n"
  printf "╰──────────────────────────────────────────────────────╯\n"
fi

# ───────────────── DISK ─────────────────
printf "\n╭─ DISK ──────────────────────────────────────────────╮\n"

df -h / | awk 'NR==2 {
  gsub("%","",$5)
  used=$5

  printf "│ Root: %3d%% ", used

  filled = int(used * 12 / 100)
  bar=""
  for(i=0;i<12;i++) bar = bar (i<filled?"█":"░")

  printf "%s                             │\n", bar
}'

printf "╰─────────────────────────────────────────────────────╯\n"