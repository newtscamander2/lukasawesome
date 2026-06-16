#!/usr/bin/env bash
# Install + enable system services and add the user to required groups.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

USER_NAME="${SUDO_USER:-$USER}"

# --- Display manager ---
case "$(cfg DISPLAY_MANAGER lightdm)" in
    lightdm)
        log "Setting up LightDM"
        pac_install lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
        run sudo systemctl enable lightdm.service
        ;;
    sddm)
        log "Setting up SDDM"
        pac_install sddm
        run sudo systemctl enable sddm.service
        ;;
    ly)
        log "Setting up ly"
        pac_install ly
        run sudo systemctl enable ly.service
        ;;
    none)
        warn "No display manager selected; configure ~/.xinitrc + startx yourself."
        ;;
    *)
        warn "Unknown DISPLAY_MANAGER='$(cfg DISPLAY_MANAGER)'; skipping."
        ;;
esac

# --- Docker ---
if enabled INSTALL_DEV; then
    log "Enabling docker and adding '$USER_NAME' to the docker group"
    run sudo systemctl enable docker.service
    run sudo usermod -aG docker "$USER_NAME"
fi

# --- VirtualBox ---
if enabled INSTALL_VIRT; then
    log "Configuring VirtualBox (group + kernel modules)"
    run sudo usermod -aG vboxusers "$USER_NAME"
    run sudo modprobe vboxdrv || warn "vboxdrv not loaded yet — reboot after install."
    warn "VirtualBox/DKMS modules require a reboot to load fully."
fi

ok "Services configured. Log out/in (or reboot) for group changes to take effect."
