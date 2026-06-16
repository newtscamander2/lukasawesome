# dotfiles

Reproducible setup for a fresh Arch Linux machine: AwesomeWM rice, Neovim,
terminal, dev toolchains, and apps — driven by one configurable installer.

## Quick start

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
```

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
