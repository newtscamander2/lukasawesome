#!/usr/bin/env bash
# Bootstrap the yay AUR helper. Idempotent: no-op if yay is already installed.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if command -v yay >/dev/null 2>&1; then
    ok "yay already installed."
    exit 0
fi

log "Installing yay AUR helper"
pac_install --needed base-devel git

# Build in a temp dir and clean up after.
BUILD_DIR="$(mktemp -d)"
run_sh "git clone https://aur.archlinux.org/yay.git '$BUILD_DIR/yay'"
run_sh "cd '$BUILD_DIR/yay' && makepkg -si --noconfirm"
run rm -rf "$BUILD_DIR"
ok "yay installed."
