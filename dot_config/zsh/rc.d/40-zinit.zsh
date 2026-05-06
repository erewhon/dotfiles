ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
    source "$ZINIT_HOME/zinit.zsh"

    # ssh-agent (load early, before turbo)
    zstyle :omz:plugins:ssh-agent lifetime 4h
    zinit snippet OMZP::ssh-agent

    # OMZ git lib provides git_current_branch (used by ggpull/ggpush etc.)
    zinit snippet OMZL::git.zsh

    # Turbo-loaded omz plugins (aliases & completions)
    zinit wait lucid for \
        OMZP::aws \
        OMZP::brew \
        OMZP::direnv \
        OMZP::docker \
        OMZP::git \
        OMZP::golang \
        OMZP::history \
        OMZP::kubectl \
        OMZP::npm

    # Third-party plugins (turbo-loaded)
    zinit wait lucid for \
        atload"_zsh_autosuggest_start" \
            zsh-users/zsh-autosuggestions \
        zsh-users/zsh-syntax-highlighting
else
    echo "[zshrc] zinit not found at $ZINIT_HOME"
fi

# Initialize completion system
autoload -Uz compinit && compinit -d "$XDG_CACHE_HOME/zsh/zcompdump-${ZSH_VERSION}"

compdef _hosts asc
compdef _hosts bsc
