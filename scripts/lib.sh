#!/usr/bin/env bash
# Shared helpers for the dotfiles installer. Sourced by the other scripts.
set -euo pipefail

# Repo root (this file lives in <repo>/scripts/).
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_FILE="${CONFIG_FILE:-$DOTFILES_DIR/install.conf}"
DRY_RUN="${DRY_RUN:-0}"

if [ -t 1 ]; then
    C_BLUE='\033[1;34m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'
    C_RED='\033[1;31m'; C_RESET='\033[0m'
else
    C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_RESET=''
fi

log()  { printf "${C_BLUE}::${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GREEN} ok${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}  ! ${C_RESET}%s\n" "$*" >&2; }
err()  { printf "${C_RED}  x ${C_RESET}%s\n" "$*" >&2; }

# run: execute a command, or just print it under DRY_RUN=1.
run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf "   ${C_YELLOW}[dry-run]${C_RESET} %s\n" "$*"
    else
        "$@"
    fi
}

# run_sh: same as run() but for a full shell string (pipes, redirects, &&).
run_sh() {
    if [ "$DRY_RUN" = "1" ]; then
        printf "   ${C_YELLOW}[dry-run]${C_RESET} %s\n" "$*"
    else
        bash -c "$*"
    fi
}

# load_config: source install.conf if present (else rely on env / defaults).
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_FILE"
    fi
}

# cfg KEY [DEFAULT]: echo the value of config variable KEY, or DEFAULT.
cfg() { local k="$1"; local d="${2:-}"; printf '%s' "${!k:-$d}"; }

# enabled KEY: true when the config flag is yes/true/1.
enabled() {
    case "$(cfg "$1" no)" in yes|true|1|YES|Yes) return 0;; *) return 1;; esac
}

# ask_yn PROMPT [default y|n]: echo yes/no. Uses default under NONINTERACTIVE=1.
ask_yn() {
    local prompt="$1"; local default="${2:-y}"; local ans hint="[Y/n]"
    [ "$default" = "n" ] && hint="[y/N]"
    if [ "${NONINTERACTIVE:-0}" = "1" ]; then
        [ "$default" = "n" ] && echo "no" || echo "yes"; return
    fi
    read -r -p "$(printf "${C_BLUE}?${C_RESET} %s %s " "$prompt" "$hint")" ans || true
    ans="${ans:-$default}"
    case "$ans" in [Yy]*) echo "yes";; *) echo "no";; esac
}

# ask_str PROMPT DEFAULT: echo a free-text answer (or DEFAULT).
ask_str() {
    local prompt="$1"; local default="${2:-}"; local ans
    if [ "${NONINTERACTIVE:-0}" = "1" ]; then echo "$default"; return; fi
    read -r -p "$(printf "${C_BLUE}?${C_RESET} %s [%s] " "$prompt" "$default")" ans || true
    echo "${ans:-$default}"
}

# require_arch: refuse to run the installer on a non-Arch system.
require_arch() {
    if [ ! -f /etc/arch-release ] && ! command -v pacman >/dev/null 2>&1; then
        err "This installer targets Arch Linux (pacman not found). Aborting."
        exit 1
    fi
}

# pac_install PKG...: install official-repo packages (idempotent).
pac_install() {
    [ "$#" -gt 0 ] || return 0
    run sudo pacman -S --needed --noconfirm "$@"
}

# aur_install PKG...: install AUR packages via yay (idempotent).
aur_install() {
    [ "$#" -gt 0 ] || return 0
    if ! command -v yay >/dev/null 2>&1 && [ "$DRY_RUN" != "1" ]; then
        warn "yay not found; run the yay bootstrap first. Skipping: $*"
        return 0
    fi
    run yay -S --needed --noconfirm "$@"
}

# aur_install_optional PKG...: try each AUR package individually, warn (don't
# fail) when one isn't available. For flaky/niche packages.
aur_install_optional() {
    local p
    for p in "$@"; do
        if [ "$DRY_RUN" = "1" ]; then
            printf "   ${C_YELLOW}[dry-run]${C_RESET} yay -S --needed %s (best-effort)\n" "$p"
            continue
        fi
        if command -v yay >/dev/null 2>&1; then
            yay -S --needed --noconfirm "$p" || warn "Optional package '$p' not available — install manually if needed."
        else
            warn "yay missing; skipping optional '$p'."
        fi
    done
}
