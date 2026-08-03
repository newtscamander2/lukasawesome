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
        # accountsservice is a hard runtime dep, not a pacman dep: without it
        # LightDM fails the org.freedesktop.Accounts user-list lookup, exits 1,
        # and burns its restart limit — VT1 stays black with no greeter.
        pac_install lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice
        run sudo systemctl enable lightdm.service
        # LightDM can start before the GPU driver is ready (fast NVMe boots),
        # leaving a black screen on VT1 that a manual restart "fixes". Make it
        # wait until logind marks the seat graphical.
        run sudo sed -i 's/^#logind-check-graphical=.*/logind-check-graphical=true/' /etc/lightdm/lightdm.conf
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

# --- Networking (NetworkManager handles wifi / eduroam) ---
if enabled INSTALL_BASE; then
    log "Enabling NetworkManager, Bluetooth, firewall and mirror refresh"
    run sudo systemctl enable NetworkManager.service
    run sudo systemctl enable bluetooth.service
    # Firewall: deny inbound, allow outbound, then enable.
    run sudo ufw default deny incoming
    run sudo ufw default allow outgoing
    run sudo ufw --force enable
    run sudo systemctl enable ufw.service
    run sudo systemctl enable reflector.timer
fi

# --- Laptop: power management + touchpad ---
if enabled LAPTOP; then
    log "Enabling TLP and installing touchpad config"
    run sudo systemctl enable tlp.service
    # tap-to-click + natural scrolling for the touchpad
    run_sh "sudo install -d /etc/X11/xorg.conf.d && sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf >/dev/null <<'EOF'
Section \"InputClass\"
    Identifier \"touchpad\"
    Driver \"libinput\"
    MatchIsTouchpad \"on\"
    Option \"Tapping\" \"on\"
    Option \"NaturalScrolling\" \"true\"
    Option \"ClickMethod\" \"clickfinger\"
EndSection
EOF"
    # Fail loudly here rather than at the next boot, when the only symptom is a
    # black screen and no way to read the logs from inside a graphical session.
    if [ "$DRY_RUN" != "1" ] && ! xorg_conf_valid /etc/X11/xorg.conf.d/30-touchpad.conf; then
        err "30-touchpad.conf is malformed (unbalanced Section/EndSection)."
        err "Refusing to continue — Xorg would fail to start and LightDM would loop."
        exit 1
    fi
fi

ok "Services configured. Log out/in (or reboot) for group changes to take effect."
