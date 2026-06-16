#!/usr/bin/env bash
# Install GPU drivers and multi-monitor / projector tooling.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

# Enable the [multilib] repo so 32-bit (lib32-*) GPU libs are installable.
enable_multilib() {
    if pacman -Sl multilib >/dev/null 2>&1; then
        ok "multilib repo already enabled."
        return 0
    fi
    log "Enabling [multilib] repository in /etc/pacman.conf"
    run_sh "sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf"
    run sudo pacman -Sy
}

pac=(arandr autorandr xorg-xrandr)   # multi-monitor + projector tooling

case "$(cfg GPU amd)" in
    amd)
        log "Installing AMD GPU drivers"
        enable_multilib
        pac+=(mesa vulkan-radeon libva-mesa-driver mesa-vdpau
              lib32-mesa lib32-vulkan-radeon xf86-video-amdgpu)
        ;;
    intel)
        log "Installing Intel GPU drivers"
        enable_multilib
        pac+=(mesa vulkan-intel intel-media-driver lib32-mesa lib32-vulkan-intel)
        ;;
    nvidia)
        log "Installing NVIDIA GPU drivers"
        enable_multilib
        pac+=(nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings linux-headers)
        ;;
    hybrid)
        log "Installing hybrid Intel+NVIDIA drivers (PRIME)"
        enable_multilib
        pac+=(mesa vulkan-intel intel-media-driver
              nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-prime linux-headers)
        ;;
    *)
        warn "Unknown GPU='$(cfg GPU)'; installing mesa only."
        pac+=(mesa)
        ;;
esac

pac_install "${pac[@]}"

cat <<'EOF'

Multi-monitor / projector notes:
  - Run `arandr` for a GUI to arrange external displays, then save the layout.
  - `autorandr --save <name>` stores a profile; it auto-applies on hotplug.
  - Mirror to a projector:
      xrandr --output HDMI-A-0 --auto --same-as eDP
  - Extend to a projector:
      xrandr --output HDMI-A-0 --auto --right-of eDP
  (Replace output names with those shown by `xrandr --query`.)
EOF

ok "GPU drivers and display tooling installed."
