#!/bin/bash
set -ou pipefail


# If a Zen window already exists, focus it instead of launching another
if hyprctl clients | grep -qi "class: zen"; then
    hyprctl dispatch focuswindow "class:^(zen)$"
    exit 0
fi

# Helium (Chromium): map Omarchy-style --private to --incognito
exec setsid uwsm-app -- zen-browser "${@/--private/--incognito}"
