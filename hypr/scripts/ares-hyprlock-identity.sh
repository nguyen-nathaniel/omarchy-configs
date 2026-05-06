#!/usr/bin/env bash
# Stable identity line: user @ host
set -euo pipefail

host="$(hostname -s 2>/dev/null || hostname)"
echo "${USER:-user}@${host}"
