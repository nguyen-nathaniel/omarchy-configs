#!/usr/bin/env bash
# Cava → Waybar JSON. Gradients are built in bash: sed cannot replace 0–7 after
# hex colors are inserted, or later rules rewrite digits inside #RRGGBB and break JSON.

#chars=(" " "▂" "▃" "▄" "▅" "▆" "▇" "█")
colors=("#42A26A" "#5BB87E" "#74CE92" "#8DE4A6" "#A6FAA0" "#C2FF95" "#DEFF8A" "#F7FF7F")
#local top_chars=(" " "▔" "▀" "█" "█" "█" "█" "█")
#local bottom_chars=(" " " " " " " " "▔" "▀" "█" "█")
#$bottom" '{text: $text}'
config_file="/tmp/bar_cava_config"
cat >"$config_file" <<'EOF'
[general]
framerate = 60
bars = 150 

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 5
EOF

pkill -f "cava -p $config_file" 2>/dev/null || true
sleep 0.05

render_line() {
	local raw="$1"
	local line="${raw//;/}"
	local top="" c d
	local top_chars=(" " "▔" "▀" "█" "█")
	local bottom_chars=(" " " " " " " " "▔" "▀" "█" "█")
	for ((i = 0; i < ${#line}; i++)); do
		c="${line:i:1}"
		case "$c" in
		[0-4])
			d=$((10#$c))
			top+="<span color='${colors[d]}'>${top_chars[d]}</span>"
			#bottom+="<span color='${colors[d]}'>${bottom_chars[d]}</span>"
			;;
		esac
	done
	jq -nc --arg text "$top" '{text: $text}'
}

cava -p "$config_file" 2>/dev/null | while IFS= read -r raw; do
	render_line "$raw"
done
