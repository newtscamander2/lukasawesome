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
        neovim                         # the editor itself (config is stowed from nvim/)
        tree-sitter-cli                # nvim-treesitter compiles grammars with this
        ripgrep fd                     # telescope live_grep + fast find_files
        unzip wget curl
        networkmanager network-manager-applet  # wifi / eduroam (802.1X); nm-applet = tray GUI
        nm-connection-editor           # GUI connection editor (nm-applet launches it for editing)
        networkmanager-openvpn         # OpenVPN GUI: import .ovpn in nm-connection-editor
        python-dbus                    # eduroam CAT installer configures NM over D-Bus (docs/eduroam-au.md)
        pipewire pipewire-pulse wireplumber pavucontrol  # audio (volume widget uses pactl)
        bluez bluez-utils blueman      # bluetooth
        playerctl                      # media-key control (play/pause/next)
        amd-ucode                      # AMD CPU microcode (harmless if Intel)
        ufw                            # firewall (public / uni networks)
        reflector                      # keep pacman mirrors fast
        rclone fuse3                   # Proton Drive mount (~/ProtonDrive)
    )
    aur+=(neofetch)                    # dropped from official repos -> AUR
fi

# --- Laptop-only essentials ---
if enabled LAPTOP; then
    pac+=(
        tlp tlp-rdw                    # battery / power management
        brightnessctl                  # screen backlight control
        xf86-input-libinput            # touchpad driver
    )
fi

# --- Developer toolchains ---
if enabled INSTALL_DEV; then
    pac+=(
        docker docker-compose docker-buildx
        gcc                            # provides g++
        clang                          # clangd + clang-format (C/C++ LSP/format)
        jdk-openjdk                    # java compile/run
        nodejs npm                     # nvim Copilot + JS tooling
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
    # texlive-most/-langextra were retired in Arch's TeX Live repackaging;
    # texlive-meta = all collections, langeuropean = Danish hyphenation etc.
    pac+=(texlive-meta texlive-langeuropean biber)
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
    aur+=(xwinwrap-git)  # maintained fork; plain 'xwinwrap' resolves to a dead bzr package
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
    # protondrive-bin and eurooffice were deleted from the AUR (gone as of 2026).
    # Proton Drive is covered by the rclone protondrive remote + user service
    # that this repo already ships (see README "Manual steps after install").
    warn "Proton Drive: no native client packaged; the rclone mount covers it."
fi

ok "Package installation complete."
