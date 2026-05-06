# History
HIST_STAMPS="yyyy-mm-dd"
HISTSIZE=1000000
SAVEHIST=$HISTSIZE
[ ! -d "$XDG_STATE_HOME/zsh" ] && mkdir -p "$XDG_STATE_HOME/zsh"
export HISTFILE="$XDG_STATE_HOME"/zsh/history
setopt EXTENDED_HISTORY

# Shell behavior
setopt AUTO_CD

# Emacs keybindings
bindkey -e

# Editor (overridden in 70-tools.zsh if nvim is installed)
export EDITOR="vi"
export VERSION_CONTROL=numbered

# GPG signing
export GPG_TTY=$(tty)

# Mirror full history with epoch timestamps for searchability later
zshaddhistory() {
    echo -n "$(date "+%s") $1" >> "$HOME/.zsh_full_history"
}
