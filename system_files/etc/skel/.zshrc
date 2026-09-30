# ---- Fastfetch ----
# RakuOS identity at shell start
fastfetch() {
    if [[ $# -eq 0 ]]; then
        command fastfetch -c "$HOME/.config/fastfetch/config.jsonc"
    else
        command fastfetch "$@"
    fi
}
fastfetch

# RakuOS Hyprland zsh config - fish-like experience
# Auto-suggestions, syntax highlighting, starship prompt, fzf, zoxide, bat.

# --- History ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt NO_BEEP

# --- Completion ---
autoload -U compinit
compinit
setopt COMPLETE_IN_WORD

# --- Utilities as defaults ---
export PAGER="bat --paging=never"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
alias cat='bat --style=plain'

# --- Eza ---
alias ls='eza -al --color=always --group-directories-first --icons'
alias la='eza -a --color=always --group-directories-first --icons'
alias ll='eza -l --color=always --group-directories-first --icons'
alias lt='eza -aT --color=always --group-directories-first --icons'
alias l.="eza -a | grep -e '^\.'"

# --- Apps ---
alias op='opencode'
alias yz='yazi'
alias nv='nvim'

# --- Podman ---
alias d='Podman'
alias dps='Podman ps'
alias dpa='Podman ps -a'
alias di='Podman images'
alias dex='Podman exec -it'
alias dlog='Podman logs -f'

# --- RakuOS (rum) ---
alias update='sudo rum system-upgrade'
alias install='sudo rum install'
alias remove='sudo rum remove'
alias search='rum search'
alias list='rum list'
alias clean='~/.config/clean/clean.sh'
alias jctl="journalctl -p 3 -xb"
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias grep='grep --color=auto'

# --- Fish-like auto-suggestions (as you type) ---
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# --- Starship prompt ---
eval "$(starship init zsh)"

# --- Transient prompt (p10k-style, karena build starship Fedora tak support zsh) ---
typeset -g _STARSHIP_FULL_PROMPT="$PROMPT"
typeset -g _STARSHIP_FULL_RPROMPT="$RPROMPT"
function _starship_transient_line_finish() {
  PROMPT='%(0?.%F{green}λ%f.%F{red}×%f) '
  RPROMPT=''
  zle reset-prompt
}
zle -N zle-line-finish _starship_transient_line_finish
function _starship_restore_prompt() {
  PROMPT="$_STARSHIP_FULL_PROMPT"
  RPROMPT="$_STARSHIP_FULL_RPROMPT"
}
add-zsh-hook precmd _starship_restore_prompt

# --- fzf (Ctrl-T pick files, Ctrl-R history, Alt-C cd) ---
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_R_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_OPTS='--height 40% --layout=reverse --border'
eval "$(fzf --zsh)"

# --- zoxide (smart cd, `z <dir>` + `cd <dir>`) ---
eval "$(zoxide init zsh)"
alias z='zoxide'
alias zi='zoxide query -i'

# --- Standard zsh behaviour ---
setopt auto_cd
setopt extended_glob
setopt interactive_comments
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt ALWAYS_TO_END

# Completion case-insensitive (ketik huruf besar/kecil bebas)
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Word navigation: Ctrl+→ / Ctrl+← lompat antar kata
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Directory shortcuts
alias -- ..='cd ..'
alias -- ...='cd ../..'
alias -- ....='cd ../../..'
alias -- -='cd -'
alias du='du -h'
alias df='df -h'
alias mkdir='mkdir -p'

# --- Syntax highlighting (must be loaded LAST) ---
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
