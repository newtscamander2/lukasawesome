# lukasawesome

Reproducible setup for a fresh Arch Linux machine: AwesomeWM rice, Neovim,
terminal, dev toolchains, and apps — driven by one configurable installer.

## Fresh Arch install (from `archinstall`)

This setup assumes a base Arch system already exists. The easiest path is the
official `archinstall` script. When prompted, choose:

- **Disk:** enable **disk encryption (LUKS)**, filesystem **btrfs** with the
  default **subvolume** layout (gives snapshot-friendly `/` and `/home` on one
  filesystem — no separate `/home` partition needed). LVM optional on top.
- **Profile / network:** select **NetworkManager** (wifi + eduroam / 802.1X).
- **Audio:** select **pipewire**.
- `archinstall` installs CPU **microcode** (`amd-ucode`) automatically.

Then reboot into the new system and run the setup:

```bash
git clone https://gitlab.com/newtscamander/lukasawesome.git ~/lukasawesome
cd ~/lukasawesome
make configure      # answer e.g. laptop = yes, GPU = amd
make install        # dry-run preview -> confirm -> install (no SSH keys needed)
make check-system   # verify everything came up correctly
make repos          # then: SSH key for GitLab/GitHub + personal repos + SSH remote
```

`pacman --needed` means anything `archinstall` already set up is skipped cleanly,
so re-installing those packages here is harmless.

## Quick start (existing system)

```bash
git clone https://gitlab.com/newtscamander/lukasawesome.git ~/lukasawesome
cd ~/lukasawesome
make install        # questionnaire -> dry-run preview -> confirm -> install
make repos          # optional: SSH key + personal repos (flips origin to SSH)
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
make bin         # link bin/ CLI tools (goat-manager, gm) into ~/.local/bin
make apps        # VSCode settings + clone cv/goat into ~/projects
make check-system # verify packages, services, audio and symlinks
```

## Black screen instead of a login prompt

If the machine boots to a black screen and `Ctrl+Alt+F1` shows nothing, switch
to a console with `Ctrl+Alt+F2`, log in, and run:

```
cd ~/lukasawesome && make repair-display
```

It reinstalls anything missing that a graphical login needs (including
`accountsservice`, which LightDM requires at runtime but pacman does not pull
in), repairs or quarantines malformed `/etc/X11/xorg.conf.d` snippets, checks
`rc.lua`, re-enables LightDM and restarts it. Every file it changes is backed
up next to the original first, and it is safe to re-run. Prefix with `DRY_RUN=1`
to see what it would do without touching anything.

If LightDM still will not start, the script prints the tail of
`/var/log/lightdm/lightdm.log` and `x-0.log` — the X server log is usually
where the real error is, since one bad config snippet aborts all of X with
`no screens found` and takes LightDM down with it.

## Syncing two machines (desktop + laptop)

Both machines clone this repo and `make stow`, so the configs are symlinks into
`~/lukasawesome`. To sync a change:

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
| `goat-manager/` | `~/.config/goat-manager` + bash completion |

`scripts/` holds the installer; `vscode/` holds settings applied by `make apps`;
`bin/` holds personal CLI tools installed by `make bin`.

## goat-manager (`gm`)

`bin/goat-manager` manages [goat](https://gitlab.com/newtscamander/goat) LaTeX
documents: which release of the library a document targets, and where coursework
lives on disk. `make bin` links it into `~/.local/bin` as both `goat-manager`
and `gm`; `make stow` installs its config and bash completion.

```bash
gm main.tex --get-version      # which goat release this document targets
gm main.tex --check-upgrade    # is a newer goat available? (exit 10 if yes)
gm main.tex --upgrade          # re-pin to the newest goat, then test-compile
```

The version a document targets is recorded as a magic comment on its first line
(`% !goat version = 0.1.4`), so it survives being copied, mailed or opened on
Overleaf. A LaTeX rollback pin (`\usepackage{goat}[=0.1.4]`), a bare date pin,
and a project-level `.goat-version`/`goat.toml` are also recognised, in that
order of precedence. `--upgrade` keeps a `.bak`, rewrites the pin, compiles the
document in a temp directory, and restores the original if that compile fails —
so upgrading can never silently break a hand-in.

Coursework is kept in one predictable tree:

```
~/aarhusuni/1semester/introtoprogramming/2026-10-05-writing-hello-world-in-python/
└── main.tex        # goat preamble, fields filled in, version pinned
    img/            # goat's \gimage / goat-img drop images here
    .latexmkrc      # pdflatex + biber + shell-escape
```

```bash
gm                                         # the tree, and every course in it
gm --create-course "Introduktion til Programmering"
gm --create-lecture "Writing hello world in Python"
gm --create-homework "Week 3" -c algo      # -c takes an alias, prefix or dir name
gm --create-report "Sorting benchmark"     # built from goat's templates/report.tex
gm --list                                  # entries in the current course
cd "$(gm --latest -c algo)"                # jump to the newest entry
gm --where                                 # what is configured and detected
```

Typed on its own, `gm` is a status view: which coursework root and semester are
in effect, where in the tree the shell currently is, and every course with its
entry count and newest entry.

```
:: /home/lukas/aarhusuni  (1semester)
   you are here: 1semester/introduktion-til-programmering

   algo                                     0 entries
   datastrukturer-og-algoritmer             1 entry     latest 2026-08-14 uge 3
   introduktion-til-programmering  (itp)    2 entries   latest 2026-08-20 lister og loekker
```

Run from inside a course directory, `--create-*` files the new entry next to its
siblings with no flags at all. Outside the tree it falls back to
`current_semester`/`current_course` from `~/.config/goat-manager/config.toml`
(this repo's `goat-manager/` package) and asks when it still cannot tell.
Edit that file to set your author name, student id, department, language, style
and course aliases; `gm --where` shows what is in effect.

## AwesomeWM themes

Five themes cycle with **Super+Shift+T**: `dr460nized` (default, Garuda-inspired
Dracula neon — hot pink on near-black), `arch` (Catppuccin Mocha), `ubuntu`
(Yaru), `windows7` (Aero), and `win11`. The active one is stored in
`~/.config/awesome/active_theme`; the terminal palette follows it (see
`alacritty/.config/alacritty/themes/`).

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
- **Proton Drive** (via rclone, mounted at `~/ProtonDrive`): run `make protondrive`
  — it walks through the one-time Proton login and enables the mount service.
  It's an unofficial backend — fine for access/backup; use Syncthing for
  always-on sync.
- **Brave policy**: `make apps` installs `/etc/brave/policies/managed/` with
  forced extensions (1Password, ColorZilla, No YouTube Shorts, Claude in
  Chrome) and Brave Rewards disabled; edit `brave/policies.json` to change.
- **EuroOffice**: best-effort AUR; if unavailable, install manually.
- **Eduroam (AU) — laptop only**: connect to Aarhus University wifi via the
  eduroam CAT installer; full walkthrough in [docs/eduroam-au.md](docs/eduroam-au.md).
  Wifi GUI is `nm-applet` in the systray (autostarted by awesome).

## Secrets

KeePassXC databases (`*.kdbx`) are gitignored and must **never** be committed.
Keep your database outside this repo.
