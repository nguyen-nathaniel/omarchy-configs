#!/usr/bin/env bash
# Cava → Waybar JSON. Gradients are built in bash: sed cannot replace 0–7 after
# hex colors are inserted, or later rules rewrite digits inside #RRGGBB and break JSON.

chars=(" " "▂" "▃" "▄" "▅" "▆" "▇" "█")
colors=("#42A26A" "#5BB87E" "#74CE92" "#8DE4A6" "#A6FAA0" "#C2FF95" "#DEFF8A" "#F7FF7F")

config_file="/tmp/bar_cava_config"
cat >"$config_file" <<'EOF'
[general]
framerate = 60
bars = 300

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

pkill -f "cava -p $config_file" 2>/dev/null || true
sleep 0.05

render_line() {
	local raw="$1"
	local line="${raw//;/}"
	local out="" c d
	for ((i = 0; i < ${#line}; i++)); do
		c="${line:i:1}"
		case "$c" in
		[0-7])
			d=$((10#$c))
			out+="<span color='${colors[d]}'>${chars[d]}</span>"
			;;
		esac
	done
	jq -nc --arg text "$out" '{text: $text}'
}

cava -p "$config_file" 2>/dev/null | while IFS= read -r raw; do
	render_line "$raw"
done
