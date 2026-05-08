#!/usr/bin/env bash
# Build and install hyprlock v0.9.5 with $PASSDISPLAYLEN + immediate label refresh on key.
# Requires: cmake, ninja, gcc, and hyprlock build deps (see https://github.com/hyprwm/hyprlock#building)
set -euo pipefail

PATCH="${HOME}/.config/hypr/patches/hyprlock-0.9.5-passdisplaylen-and-key-refresh.patch"
TAG="v0.9.5"
WORKDIR="${HYPRLOCK_BUILD_DIR:-${TMPDIR:-/tmp}/hyprlock-build-${TAG}}"

if ! command -v cmake >/dev/null; then
  echo "cmake is not installed. On Arch: sudo pacman -S --needed cmake ninja base-devel" >&2
  exit 1
fi

if [[ ! -f "${PATCH}" ]]; then
  echo "Missing patch: ${PATCH}" >&2
  exit 1
fi

rm -rf "${WORKDIR}"
git clone --depth 1 --branch "${TAG}" https://github.com/hyprwm/hyprlock.git "${WORKDIR}"
cd "${WORKDIR}"
git apply "${PATCH}"

cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
cmake --build ./build --config Release -j"$(nproc 2>/dev/null || echo 4)"

echo "Build finished: ${WORKDIR}/build/hyprlock"
echo "Install system-wide (overwrites /usr/bin/hyprlock):"
echo "  sudo cmake --install build"
