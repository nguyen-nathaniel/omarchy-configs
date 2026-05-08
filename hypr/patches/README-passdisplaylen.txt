Hyprlock local patches (tag v0.9.5)

Combined patch (recommended)
------------------------------
File: hyprlock-0.9.5-passdisplaylen-and-key-refresh.patch

1. IWidget.cpp: new label/substitution variable $PASSDISPLAYLEN (UTF-8 display
   length of the password buffer from getPasswordBufferDisplayLen()).
2. hyprlock.cpp: after handleKeySym mutates the buffer, call
   enqueueForceUpdateTimers() so cmd[] labels refresh on the next frame instead
   of only on the label timer (e.g. 200 ms).

Use with ~/.config/hypr/hyprlock.conf:
  text = cmd[update:200] /home/nate/.config/hypr/scripts/ares-hyprlock-scan.sh $PASSDISPLAYLEN

Stock /usr/bin/hyprlock from pacman does NOT include this; the scan line will
not switch when typing until you install a binary built with the patch.

Build helper
------------
  chmod +x ~/.config/hypr/patches/build-patched-hyprlock.sh
  ~/.config/hypr/patches/build-patched-hyprlock.sh
  sudo cmake --install /tmp/hyprlock-build-v0.9.5/build   # path printed at end

Or manual:
  git clone --depth 1 --branch v0.9.5 https://github.com/hyprwm/hyprlock.git
  cd hyprlock && git apply ~/.config/hypr/patches/hyprlock-0.9.5-passdisplaylen-and-key-refresh.patch
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"$(nproc)"
  sudo cmake --install build

Legacy single-file patch (IWidget only)
---------------------------------------
hyprlock-0.9.5-passdisplaylen.patch — superseded by the combined patch above.

Upstream
--------
Consider opening a PR to hyprwm/hyprlock for $PASSDISPLAYLEN (and optionally
key-triggered label refresh) so you can drop local builds after it merges.

Verification (2026-02-01)
-------------------------
System /usr/bin/hyprlock was pacman v0.9.5 (stock); substitution requires the
patched binary. After install: lock once and confirm scan.sh switches to the
passphrase line when typing.
