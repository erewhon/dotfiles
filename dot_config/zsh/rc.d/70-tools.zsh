# Pager: bat (or batcat on Debian) for syntax-highlighted paging
if command -v bat &> /dev/null; then
    export BAT_THEME=Dracula
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    alias less=bat
    alias gitd='git diff --name-only --diff-filter=d | xargs bat --diff --show-all'
    function tailf() { tail -f "$@" | bat --paging=never -l log }
    function batdiff() {
        git diff --name-only --diff-filter=d | xargs bat --diff
    }
elif [[ -f /usr/bin/batcat ]]; then
    export BAT_THEME=Dracula
    export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
    alias less=batcat
    alias gitd='git diff --name-only --diff-filter=d | xargs batcat --diff --show-all'
    function tailf() { tail -f "$@" | batcat --paging=never -l log }
else
    export PAGER=less
    alias gitd='git diff'
    alias tailf='tail -f'
fi

# eza for ls
if command -v eza 1>/dev/null 2>&1; then
    unalias l 2>/dev/null
    unalias ll 2>/dev/null
    unalias ls 2>/dev/null

    export EZA_GRID_ROWS=30

    function ls() {
        eza --icons --all --group-directories-first --grid "$@"
    }

    function ll() {
        eza -abghHl --time-style=long-iso --group-directories-first            --git --grid --color=always "$@"
    }

    function lll() {
        eza -abghHl --time-style=long-iso --group-directories-first --extended --git --grid --color=always "$@" | bat --style=plain
    }

    alias tree='eza -abghHl --time-style=long-iso --tree --level=3 --color=always'
    alias l=ll
fi

# nvim
if command -v nvim 1>/dev/null 2>&1; then
    alias vi=nvim
    export EDITOR="nvim"
fi

# duf
if command -v duf 1>/dev/null 2>&1; then
    alias df=duf
fi

# Debian's renamed fd
if command -v fd-find &> /dev/null; then
    alias fd=fd-find
fi

# rlwrap for readline-less REPLs / netcat
if command -v rlwrap &> /dev/null; then
    alias rl='rlwrap'
    alias nc='rlwrap nc'
fi

# zoxide directory jumper
if command -v zoxide 1>/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# stern (k8s log viewer) completions
if command -v stern 1>/dev/null 2>&1; then
    source <(stern --completion=zsh)
fi

# atuin shell history (replaces McFly)
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# asciiquarium
if command -v asciiquarium 1>/dev/null 2>&1; then
    alias aq=asciiquarium
fi

# wx — weather popup if tmux supports it, otherwise just curl
if command -v tmux &> /dev/null; then
    TMUX_VERSION=$( tmux -V | awk '{print $2}' )
    if [[ "$TMUX_VERSION" == "next-3.3" ]]; then
        alias wx='tmux popup -w 150 -h 45 -KR "curl wttr.in/Houston"'
    else
        alias wx='curl wttr.in/Houston'
    fi
fi

# fzf + ripgrep + bat: fuzzy finders, previews, and pickers
if command -v fzf &> /dev/null; then
    alias gitb='git branch | fzf-tmux -d 15'

    # Fuzzy preview
    alias fp="fzf --preview 'bat --style=full --color=always --line-range :500 {}' --preview-window '~3'"

    # Search with rg, filter in fzf, preview in bat
    INITIAL_QUERY=""
    RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
    function fsp() {
        FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
        fzf --bind "change:reload:$RG_PREFIX {q} || true" \
            --ansi --disabled --query "$INITIAL_QUERY" \
            --layout=reverse \
            --delimiter : \
            --preview 'bat --style=full --show-all --color=always --highlight-line {2} {1}' \
            --preview-window '~3:+{2}+3/2'
    }

    # Git history preview
    alias ghp="git log --oneline | fzf --multi --preview 'git show {+1} | bat --style=full --color=always'"

    function gdp() {
        preview="git diff $@ --color=always -- {-1}"
        git diff $@ --name-only | fzf -m --ansi --preview $preview
    }

    # Pick outdated brew packages and upgrade. Adapted from
    # https://github.com/thirteen37/fzf-brew/blob/master/fzf-brew.plugin.zsh
    function bui() {
        local inst=$(brew outdated | fzf --query="$1" -m \
                                         --preview 'HOMEBREW_COLOR=true brew info {}' \
                                         --bind "ctrl-space:execute-silent(brew home {})")

        if [[ $inst ]]; then
            for prog in $(echo $inst); do; brew upgrade $prog; done;
        fi
    }
fi

# sesh: tmux session picker bound to Alt-s
if command -v sesh &> /dev/null; then
    function sesh-sessions() {
      {
        exec </dev/tty
        exec <&1
        local session
        session=$(sesh list -t -c | fzf --height 40% --reverse --border-label ' sesh ' --border --prompt '⚡  ')
        zle reset-prompt > /dev/null 2>&1 || true
        [[ -z "$session" ]] && return
        sesh connect $session
      }
    }

    zle     -N             sesh-sessions
    bindkey -M emacs '\es' sesh-sessions
    bindkey -M vicmd '\es' sesh-sessions
    bindkey -M viins '\es' sesh-sessions
fi

# cowsay-based fun
if command -v cowsay &> /dev/null; then
    gnusay() {
        cowsay -f gnu "$@"
    }

    whocall() {
        cowsay -f ghostbusters Who you Gonna Call | lolcat
    }
fi

# bun completions
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# asdf (homebrew install)
if command -v brew &> /dev/null; then
    _asdf_dir="$(brew --prefix asdf 2>/dev/null)"
    [[ -n "$_asdf_dir" && -s "$_asdf_dir/libexec/asdf.sh" ]] && source "$_asdf_dir/libexec/asdf.sh"
    unset _asdf_dir
fi

# broot launcher
[[ -s "$HOME/.config/broot/launcher/bash/br" ]] && source "$HOME/.config/broot/launcher/bash/br"

# Fallback path for system zsh-syntax-highlighting (zinit also loads it)
[[ -s "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
    source "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Host-local credentials, if present
[[ -s "$HOME/creds.env" ]] && source "$HOME/creds.env"

# Project-specific PATH additions (only added if dir exists on this host)
_project_paths=(
    "$HOME/Projects/erewhon/content-tools"
    "$HOME/.claude/local"
    "$HOME/Projects/erewhon/dx"
)

for dir in $_project_paths; do
    [[ -d "$dir" ]] && export PATH="${dir}:${PATH}"
done
unset _project_paths
