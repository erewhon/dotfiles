# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ,=popd
alias c=cd
alias d=dirs
alias j=jobs
alias p=pushd

# Shortcuts
alias s=ssh
alias e='emacsclient --no-wait --create-frame'
alias mc='mc -x'
alias play=ansible-playbook

# Read-only markdown viewer: a separate nvim config in ~/.config/mdview
# (rendered headings, TOC with T, zen mode with Z, q to quit).
alias md='NVIM_APPNAME=mdview nvim -R'
# mdv, the same viewer in Neovide, is a function in 60-functions.zsh.

# Git
alias gdh='git diff HEAD'
alias gupv='git pull --rebase --autostash -v'
alias gw='git worktree'
alias gitzip="git archive --format=zip HEAD ':!*.gitignore' -o ${PWD##*/}.zip"

# History snapshot
alias histback='fc -W ~/.local/state/zsh/history.$( date +%Y%m%d.%H%M )'

# TUIs
alias post=posting    # API TUI
alias sql=harlequin   # SQL TUI

# AI
alias cl='claude --dangerously-skip-permissions'
alias oc=opencode
alias tm=task-master
