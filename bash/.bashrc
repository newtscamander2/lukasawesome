#
# ~/.bashrc — managed by dotfiles
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# --- Aliases ---
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -lah'
alias ..='cd ..'

# --- History ---
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

# --- Powerline-style prompt: Arch glyph + user@host + path + git branch ---
# Needs a Nerd Font (the terminal uses FiraCode Nerd Font).
__dotfiles_prompt() {
    local arch=$''        # Arch Linux logo
    local sep=$''         # powerline right separator
    local branch=$''      # git branch glyph

    # 256-colour segments (bg ; fg)
    local u_bg=24  u_fg=255     # user@host: blue
    local p_bg=240 p_fg=255     # path: grey
    local g_bg=28  g_fg=232     # git: green

    local gb
    gb=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    local p="\[\e[48;5;${u_bg};38;5;${u_fg}m\] ${arch} \u@\h \[\e[0m\]"
    if [[ -n $gb ]]; then
        p+="\[\e[48;5;${p_bg};38;5;${u_bg}m\]${sep}\[\e[48;5;${p_bg};38;5;${p_fg}m\] \w \[\e[0m\]"
        p+="\[\e[48;5;${g_bg};38;5;${p_bg}m\]${sep}\[\e[48;5;${g_bg};38;5;${g_fg}m\] ${branch} ${gb} \[\e[0m\]"
        p+="\[\e[38;5;${g_bg}m\]${sep}\[\e[0m\] "
    else
        p+="\[\e[48;5;${p_bg};38;5;${u_bg}m\]${sep}\[\e[48;5;${p_bg};38;5;${p_fg}m\] \w \[\e[0m\]"
        p+="\[\e[38;5;${p_bg}m\]${sep}\[\e[0m\] "
    fi
    PS1="$p"
}
PROMPT_COMMAND=__dotfiles_prompt

# --- University notes: one git worktree per course ---
# A program cannot change its parent shell's directory, so opening a course has
# to be a function. gm does the work (branch, worktree, course directory) and
# prints where to stand; -q keeps its own chatter on stderr so this stays clean.
#   class            list the courses
#   class math       open math, creating it the first time
# These two capture gm's stdout to cd into it, so anything gm prints that is
# NOT a path must never reach `cd` -- `class --help` once tried to cd into the
# whole help text. Help is forwarded uncaptured, and whatever comes back is
# checked for being a directory before it is used.
class() {
    case "${1-}" in
        -h|--help) gm --help; return ;;
    esac
    if [ "$#" -eq 0 ]; then
        gm --classes
        return
    fi
    local dir
    dir="$(gm --class "$@" -q)" || return
    if [ -d "$dir" ]; then cd "$dir"; else printf '%s\n' "$dir"; fi
}

# Back to the top of the notes repository from wherever you are -- inside an
# entry that is five levels of "cd ..", which is tedious and easy to miscount.
# `notes main` goes to the merged tree, which is where you read across courses.
# gm resolves the destination, so a wrong name is explained ("that is a course,
# open it with: class danish") instead of the shell reporting a path you never
# typed.
notes() {
    case "${1-}" in
        -h|--help) gm --help; return ;;
    esac
    local dir
    dir="$(gm --root -q "$@")" || return
    if [ -d "$dir" ]; then cd "$dir"; else printf '%s\n' "$dir"; fi
}

# Everything not safely on GitLab yet. Worth a glance before closing the laptop.
alias pending='gm --pending'

# Is the password database actually syncing? `kpsync` on its own answers that;
# `kpsync sync` forces a run, `kpsync allow-delete` unblocks a refused deletion.
kpsync() { bash "$HOME/lukasawesome/scripts/keepassxc-sync.sh" "${1:-status}"; }

# --- PATH ---
# Personal CLI tools (this repo's bin/, installed by 'make bin') and anything
# else that installs into ~/.local/bin, e.g. goat's goat-img / goat-lint.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# --- Tooling env ---
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# systemd user ssh-agent (ssh-agent.socket)
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
