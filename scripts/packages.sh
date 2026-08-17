#!/usr/bin/env bash
# Install package groups based on install.conf flags.
# Official-repo packages via pacman; AUR packages via yay.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

pac=()   # official repo
aur=()   # AUR (need yay)

# --- Always: core tooling needed for the dotfiles themselves ---
# less is git's built-in default pager, but Arch dropped it from the 'base'
# meta-package and nothing here depends on it, so 'git log'/'git branch' die
# with "unable to execute pager 'less'" on a fresh install. Also the man pager.
#
# bash-completion is what loads this repo's completions/ files on demand --
# 'make bin' links them into ~/.local/share/bash-completion/completions, but
# nothing reads that directory unless the package is installed. Without it,
# 'gm --<tab>' and 'class <tab>' silently do nothing, which reads as a broken
# completion script rather than a missing package.
pac+=(git stow base-devel less bash-completion)

# --- Base desktop apps ---
if enabled INSTALL_BASE; then
    pac+=(
        # The desktop itself. These were missing: the repo stowed configs for
        # awesome and alacritty and enabled LightDM, so a fresh machine reached
        # a login greeter with no window manager to start and no terminal to
        # recover from. xterm is the fallback for exactly that morning.
        awesome                        # the window manager (config stowed from awesome/)
        alacritty                      # the terminal (config stowed from alacritty/)
        xterm                          # fallback terminal, for when alacritty will not start
        zathura zathura-pdf-mupdf      # PDF viewer (used by nvim/vimtex + vscode)
        rofi feh                       # launcher + wallpaper
        keepassxc                      # password manager
        gnome-keyring                  # org.freedesktop.secrets: nm-applet stores the
                                       # eduroam password here, unlocked at login by PAM.
                                       # Without it eduroam re-prompts after every suspend.
        dolphin                        # file manager
        flameshot                      # screenshots
        timeshift                      # system snapshots/backup
        vicious                        # awesome widget library (wibar stats)
        xdotool xorg-xrandr            # window/display helpers
        xorg-xset                      # rc.lua sets keyboard repeat rate (xset r rate)
        jq                             # wallpaper-fetch-bands.sh parses Commons API JSON
        imagemagick                    # wallpaper-prep.sh post-processes wallpapers with 'magick'
        ttf-firacode-nerd noto-fonts noto-fonts-emoji
        noto-fonts-cjk                 # CJK glyphs; without it they render as boxes
        ttf-liberation                 # metric-compatible Arial/Times/Courier — documents
                                       # from other people keep their layout
        ttf-dejavu gnu-free-fonts      # wide-coverage fallbacks
        neovim                         # the editor itself (config is stowed from nvim/)
        tree-sitter-cli                # nvim-treesitter compiles grammars with this
        ripgrep fd                     # telescope live_grep + fast find_files
        unzip wget curl
        networkmanager network-manager-applet  # wifi / eduroam (802.1X); nm-applet = tray GUI
        nm-connection-editor           # GUI connection editor (nm-applet launches it for editing)
        networkmanager-openvpn         # OpenVPN GUI: import .ovpn in nm-connection-editor
        python-dbus                    # eduroam CAT installer configures NM over D-Bus (docs/eduroam-au.md)
        pipewire pipewire-pulse wireplumber pavucontrol  # audio (volume widget uses pactl)
        pipewire-alsa                  # ALSA apps reach pipewire; without it they are silent
        gst-plugin-pipewire            # GStreamer bridge (screen capture, some media apps)
        sof-firmware                   # Sound Open Firmware — most modern laptops have NO
                                       # audio at all without it
        cava                           # audio visualizer (bottom-edge wave in rc.lua)
        bluez bluez-utils blueman      # bluetooth
        playerctl                      # media-key control (play/pause/next) + rc.lua "now playing" panel
        light-locker                   # lock to lightdm greeter (Super+Escape + 5 min idle, rc.lua)
        xclip                          # X clipboard CLI: nvim unnamedplus provider + clipboard plumbing
        amd-ucode                      # AMD CPU microcode (harmless if Intel)
        ufw                            # firewall (public / uni networks)
        reflector                      # keep pacman mirrors fast
        rclone fuse3                   # Proton Drive mount (~/ProtonDrive) + KeePassXC bisync
        # Qt/KDE theming so Dolphin & friends match the WM. The KDE platform
        # theme (plasma-integration) is the load-bearing piece: without it KF6
        # apps ignore kdeglobals entirely and render stock light Breeze, no
        # matter what qt5ct/Kvantum are told. QT_QPA_PLATFORMTHEME=kde is set
        # in /etc/environment by apps.sh.
        breeze                         # Qt widget style (icons already via breeze-icons)
        plasma-integration             # KDE platform theme for Qt6 apps (Dolphin)
        plasma5-integration            # ...and for any remaining Qt5 apps
        papirus-icon-theme             # icon fallback when candy-icons is unavailable
        htop tree xsel                 # process viewer, directory listing, X clipboard
        xdg-utils                      # xdg-open: "open this PDF" from a terminal or latexmk
        vim                            # fallback editor for when the neovim config is broken
        sl                             # a train, for when you type it instead of ls
        smartmontools                  # SMART monitoring — warns before a disk takes the
                                       # notes and the password database with it
        zram-generator                 # compressed swap in RAM (see /etc/systemd/zram-generator.conf)
        plymouth                       # boot splash. NOTE: also needs an mkinitcpio hook,
                                       # which this repo does not configure yet
        cups cups-pk-helper system-config-printer   # printing (AU printers)
        remmina freerdp                # remote desktop (RDP)
        nmap                           # network discovery / port scanning
        easy-rsa                       # small certificate authority, for OpenVPN
        metasploit                     # pentesting framework (large: ~1 GB)
        obsidian                       # markdown knowledge base
    )
    aur+=(neofetch)                    # dropped from official repos -> AUR
    aur+=(rofi-greenclip)              # clipboard history daemon behind Super+V (clipboard-menu.sh)
    aur+=(catppuccin-cursors-mocha)    # cursor theme for the arch (Mocha) theme
    aur+=(sweet-gtk-theme-dark)        # GTK side of the Dr460nized look
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

# --- Proton VPN (official GUI app) ---
if enabled INSTALL_VPN; then
    pac+=(libappindicator-gtk3)  # tray icon support (best-effort under awesome)
    aur+=(proton-vpn-gtk-app)    # official Proton VPN Linux client
fi

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

# --- Dr460nized look: -git theme packages, best-effort ---
# Git builds that occasionally break, and everything degrades gracefully:
# without candy-icons the GTK/Qt writers fall back to Papirus-Dark, without
# Sweet-cursors the cursor block is skipped. candy-icons-git is a large clone —
# expect minutes, not seconds. (There is no Sweet Kvantum theme in the AUR;
# the Qt side is Breeze + the Dr460nized KDE colour scheme instead.)
if enabled INSTALL_BASE; then
    log "Theme packages (best-effort)"
    aur_install_optional candy-icons-git sweet-cursors-git
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
