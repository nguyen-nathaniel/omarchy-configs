#!/usr/bin/env bash

# Name of your terminal + app combo (adjust if needed)
APP_CMD="spotify_player"
TERMINAL="alacritty"  # or kitty, foot, etc.

# Check if spotify-player is already running
CLASS="spotify-tui"

if hyprctl clients | grep -q "$CLASS"; then
    hyprctl dispatch focuswindow "class:^($CLASS)$"
else
    $TERMINAL --class $CLASS -e $APP_CMD &
fi
