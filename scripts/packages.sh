#!/usr/bin/env bash
# Install package groups based on install.conf flags.
# Official-repo packages via pacman; AUR packages via yay.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

pac=()   # official repo
aur=()   # AUR (need yay)

# --- Always: core tooling needed for the dotfiles themselves ---
pac+=(git stow base-devel)

# --- Base desktop apps ---
if enabled INSTALL_BASE; then
    pac+=(
        zathura zathura-pdf-mupdf      # PDF viewer (used by nvim/vimtex + vscode)
        rofi feh                       # launcher + wallpaper
        keepassxc                      # password manager
        dolphin                        # file manager
        flameshot                      # screenshots
        timeshift                      # system snapshots/backup
        vicious                        # awesome widget library (wibar stats)
        xdotool xorg-xrandr            # window/display helpers
        ttf-firacode-nerd noto-fonts noto-fonts-emoji
        unzip wget curl
    )
    aur+=(neofetch)                    # dropped from official repos -> AUR
    aur+=(code-minimap)                # binary backend for nvim minimap.vim
fi

# --- Developer toolchains ---
if enabled INSTALL_DEV; then
    pac+=(
        docker docker-compose docker-buildx
        gcc                            # provides g++
        jdk-openjdk                    # java compile/run
        python python-pip
        tmux
        ansible                        # ansible-vault ships with ansible
        kubectl helm minikube k9s      # kubernetes tooling
    )
fi

# --- Virtualization / Windows emulation ---
if enabled INSTALL_VIRT; then
    pac+=(wine virtualbox virtualbox-host-dkms linux-headers)
fi

# --- Media / creative ---
if enabled INSTALL_MEDIA; then
    pac+=(obs-studio gimp shotcut)
    aur+=(kazam)                       # screen recorder
fi

# --- LaTeX (texlive) ---
if enabled INSTALL_TEXLIVE; then
    pac+=(texlive-most texlive-langextra biber)
fi

# --- VSCode OSS (config applied separately by apps.sh) ---
if enabled INSTALL_VSCODE; then
    pac+=(code)
fi

# --- AUR apps ---
enabled INSTALL_BROWSER && aur+=(brave-bin)
enabled INSTALL_CLAUDE  && aur+=(claude-code)
enabled INSTALL_LVM_GUI && aur+=(kvpm)

# --- Video wallpaper deps (opt-in) ---
if enabled VIDEO_WALLPAPER; then
    pac+=(mpv)
    aur+=(xwinwrap)
fi

log "Official packages (${#pac[@]}): ${pac[*]}"
pac_install "${pac[@]}"

if [ "${#aur[@]}" -gt 0 ]; then
    log "AUR packages (${#aur[@]}): ${aur[*]}"
    aur_install "${aur[@]}"
fi

# --- Best-effort / niche (no dependable package) ---
if enabled INSTALL_OPTIONAL; then
    log "Best-effort optional packages (may need manual steps)"
    # Proton Drive has no official Linux client; protondrive-bin is community-maintained.
    # EuroOffice is niche; the AUR name varies. Failures here are non-fatal.
    aur_install_optional protondrive-bin eurooffice
    warn "Proton Drive: if protondrive-bin is unavailable, use rclone's Proton Drive backend."
fi

ok "Package installation complete."
