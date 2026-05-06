#!/bin/bash
set -ou pipefail

# Helium (Chromium): map Omarchy-style --private to --incognito
exec setsid uwsm-app -- vivaldi "${@/--private/--incognito}"
