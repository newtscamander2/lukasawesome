# dotfiles

Reproducible setup for a fresh Arch Linux machine: AwesomeWM rice, Neovim,
terminal, dev toolchains, and apps — driven by one configurable installer.

## Fresh Arch install (from `archinstall`)

These dotfiles assume a base Arch system already exists. The easiest path is the
official `archinstall` script. When prompted, choose:

- **Disk:** enable **disk encryption (LUKS)**, filesystem **btrfs** with the
  default **subvolume** layout (gives snapshot-friendly `/` and `/home` on one
  filesystem — no separate `/home` partition needed). LVM optional on top.
- **Profile / network:** select **NetworkManager** (wifi + eduroam / 802.1X).
- **Audio:** select **pipewire**.
- `archinstall` installs CPU **microcode** (`amd-ucode`) automatically.

Then reboot into the new system and run the dotfiles:

```bash
git clone git@gitlab.com:newtscamander/lukasawesome.git ~/dotfiles
cd ~/dotfiles
make configure      # answer e.g. laptop = yes, GPU = amd
make install        # dry-run preview -> confirm -> install
make check-system   # verify everything came up correctly
```

`pacman --needed` means anything `archinstall` already set up is skipped cleanly,
so re-installing those packages here is harmless.

## Quick start (existing system)

```bash
git clone git@gitlab.com:newtscamander/lukasawesome.git ~/dotfiles
cd ~/dotfiles
make install        # questionnaire -> dry-run preview -> confirm -> install
```

`make install` first asks how you want the machine configured (writing
`install.conf`), prints exactly what it will do, and only then — after you
confirm — makes any changes.

## Make targets

```
make help        # list targets
make configure   # (re)run the questionnaire -> install.conf
make plan        # dry-run: print every action, change nothing
make install     # full install
```

Re-runnable pieces (all read `install.conf`):

```
make yay         # bootstrap the yay AUR helper
make packages    # install package groups
make drivers     # GPU drivers + multi-monitor / projector tooling
make services    # display manager, docker, virtualbox
make stow        # symlink config packages into $HOME (GNU Stow)
make apps        # VSCode settings + clone cv/goat into ~/projects
make check-system # verify packages, services, audio and symlinks
```

## Syncing two machines (desktop + laptop)

Both machines clone this repo and `make stow`, so the configs are symlinks into
`~/dotfiles`. To sync a change:

1. On the machine you edited: `git add -A && git commit && git push`.
2. On the other machine: `git pull` (NOT just `git fetch` — fetch downloads but
   doesn't update your files; pull updates the symlinked configs in place).

`install.conf` and `*.kdbx` are gitignored, so per-machine choices and your
KeePassXC database never sync through git (sync the `.kdbx` via Syncthing/Proton).

## Layout

The repo is organised into [GNU Stow](https://www.gnu.org/software/stow/)
packages; `make stow` symlinks each into `$HOME`:

| Package      | Symlinks to            |
| ------------ | ---------------------- |
| `awesome/`   | `~/.config/awesome`    |
| `nvim/`      | `~/.config/nvim`       |
| `tmux/`      | `~/.config/tmux`       |
| `alacritty/` | `~/.config/alacritty`  |

`scripts/` holds the installer; `vscode/` holds settings applied by `make apps`.

## AwesomeWM themes

Four themes cycle with **Super+Shift+T**: `arch` (default, Catppuccin Mocha),
`ubuntu` (Yaru), `windows7` (Aero), and `win11`. The active one is stored in
`~/.config/awesome/active_theme`.

- **Super+F1** shows all keybindings, including Neovim and Claude Code cheatsheets.
- Volume / brightness / media hardware keys (`XF86*`) are bound (pactl, brightnessctl, playerctl).
- Pranks (Escape dismisses; nothing actually crashes): **Super+Shift+U** = fake "Working on updates" screen, **Super+Shift+B** = fake Blue Screen of Death.
- A random philosopher quote (English) appears on the desktop, refreshed each
  AwesomeWM restart.
- Video wallpaper (xwinwrap + mpv) is opt-in; enable it in the questionnaire.

## Manual steps after install

- **GitHub Copilot**: open Neovim and run `:Copilot setup` to authenticate.
- **Claude Code**: run `claude` and follow the login prompt.
- **Docker / VirtualBox**: log out/in (or reboot) for group membership to apply.
- **Proton Drive / EuroOffice**: best-effort AUR; if unavailable, install
  manually (for Proton Drive, rclone's Proton Drive backend works well).

## Secrets

KeePassXC databases (`*.kdbx`) are gitignored and must **never** be committed.
Keep your database outside this repo.
