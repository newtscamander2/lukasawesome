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

# --- Tooling env ---
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
