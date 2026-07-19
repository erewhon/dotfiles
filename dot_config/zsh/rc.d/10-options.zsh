# History
HIST_STAMPS="yyyy-mm-dd"
HISTSIZE=1000000
SAVEHIST=$HISTSIZE
[ ! -d "$XDG_STATE_HOME/zsh" ] && mkdir -p "$XDG_STATE_HOME/zsh"
export HISTFILE="$XDG_STATE_HOME"/zsh/history
setopt EXTENDED_HISTORY        # record epoch + duration for each command
setopt INC_APPEND_HISTORY      # flush each command to $HISTFILE as it's entered,
                               # not just on clean exit. Without this, tmux/SSH
                               # shells that are killed/detached/rebooted lose all
                               # their history (was dropping ~half of commands).
setopt HIST_FCNTL_LOCK         # fcntl() locking for safe concurrent writes from
                               # many tmux panes at once (zsh 5.1+)
setopt HIST_REDUCE_BLANKS      # tidy superfluous whitespace before saving
# Deliberately NOT setting HIST_IGNORE_DUPS / HIST_IGNORE_ALL_DUPS: the raw zsh
# history is kept complete (atuin + ~/.zsh_full_history handle search/dedup).
# Optional opt-ins if wanted later:
#   setopt SHARE_HISTORY       # also import other sessions' commands live (interleaves panes)
#   setopt HIST_IGNORE_SPACE   # skip commands typed with a leading space (secrets escape hatch)

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
