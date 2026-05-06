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
