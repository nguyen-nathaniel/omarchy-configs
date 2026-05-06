#!/usr/bin/env bash
set -euo pipefail

# ───────────────── BOX WIDTH CONTROL ─────────────────
WIDTH=52

line() {
  # Ensure string fits within width by trimming and handling multi-byte chars
  local s="$1"
  local trimmed
  trimmed=$(echo "$s" | awk -v w="$WIDTH" '{
    n=length($0)
    if (n>w) {
      printf "%s…", substr($0,1,w-1)
    } else {
      printf "%s", $0
    }
  }')
  printf "│ %-*s │\n" "$WIDTH" "$trimmed"
}

bar() {
  local pct=$1
  local w=12
  local filled=$(( pct * w / 100 ))
  local out=""
  for ((i=0;i<w;i++)); do
    [[ $i -lt $filled ]] && out+="█" || out+="░"
  done
  printf "%s" "$out"
}

# ───────────────── HEADER ─────────────────
printf "╭─ HARDWARE ───────────────────────────────────────────╮\n"

# ───────────────── CPU ─────────────────
cpu_model=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ //')
cpu_freq=$(awk -F: '/cpu MHz/ {printf "%.2f GHz", $2/1000; exit}' /proc/cpuinfo)

line "CPU  $cpu_model"

# ───────────────── GPU ─────────────────
gpu="Unknown GPU"

if command -v nvidia-smi &>/dev/null; then
  gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
elif command -v lspci &>/dev/null; then
  gpu=$(lspci | grep -i 'vga\|3d' | head -n1 | cut -d ':' -f3- | sed 's/^ //')
fi

# Split gpu string into multiple lines if too wide
if [[ "${#gpu}" -gt $((WIDTH - 5)) ]]; then
  # Split at spaces so words don't break, if possible
  g1=$(echo "$gpu" | cut -c -$((WIDTH-5)))
  rest=$(echo "$gpu" | cut -c $((WIDTH-4))-)
  line "GPU  $g1"
  while [[ -n "$rest" ]]; do
    gline=$(echo "$rest" | cut -c 1-$WIDTH)
    rest=$(echo "$rest" | cut -c $((WIDTH+1))-)
    line "     $gline"
  done
else
  line "GPU  $gpu"
fi

# ───────────────── DISPLAY ─────────────────
# ───────────────── DISPLAY ─────────────────
res=""
rate=""

if command -v hyprctl &>/dev/null; then
  # Wayland (Hyprland)
  res=$(hyprctl monitors -j 2>/dev/null | grep -m1 '"width"' | awk '{print $2}' | tr -d ',')
  height=$(hyprctl monitors -j 2>/dev/null | grep -m1 '"height"' | awk '{print $2}' | tr -d ',')
  rate=$(hyprctl monitors -j 2>/dev/null | grep -m1 '"refreshRate"' | awk '{print int($2)}' | tr -d ',')

  if [[ -n "$res" && -n "$height" ]]; then
    res="${res}x${height}"
  fi
else
  # X11 fallback
  res=$(xrandr 2>/dev/null | awk '/\*/ {print $1; exit}' || true)
  rate=$(xrandr 2>/dev/null | awk '/\*/ {print $2; exit}' | tr -d '+' || true)
fi

if [[ -n "$res" && -n "$rate" ]]; then
  line "DISP ${res} @ ${rate}Hz"
else
  line "DISP Unknown"
fi

# ───────────────── DISK ─────────────────
disk_info=$(df -h / | awk 'NR==2 {gsub("%","",$5); print $3, $2, $5}')
read -r disk_used disk_total disk_pct <<< "$disk_info"
line "DISK ${disk_used} / ${disk_total} (${disk_pct}%)"

# ───────────────── MEMORY ─────────────────
mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
used=$((mem_total - mem_avail))
pct=$((used * 100 / mem_total))

to_gib() {
  printf "%.2f" "$(awk "BEGIN {print $1/1048576}" <<< "$1")"
}

line "MEM  $(to_gib $used) / $(to_gib $mem_total) GiB (${pct}%)"


# ───────────────── FOOTER ─────────────────
printf "╰──────────────────────────────────────────────────────╯\n"