# Login-shell-only behaviors: greeting, motd, upstream-dotfiles check
[[ -o login ]] || return

# Daily fastfetch greeting (random background image if available)
NOW=$( date +'%F' )

if ! cmp -s $XDG_CACHE_HOME/.last_fastfetch <( echo $NOW ); then
    echo $NOW > $XDG_CACHE_HOME/.last_fastfetch

    if command -v fastfetch 2>&1 > /dev/null; then
        IMAGE_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/fastfetch/backgrounds"
        if [[ -z "$TMUX" ]] && [[ -d "$IMAGE_ROOT" ]] && [[ -n "$(ls -A "$IMAGE_ROOT" 2>/dev/null)" ]]; then
            ls -1 "$IMAGE_ROOT/" | \
                   shuf -n 1 | \
                   xargs -I '{}' fastfetch --logo "$IMAGE_ROOT/{}"
        else
            fastfetch
        fi
    fi
fi

# Once-daily background check for upstream chezmoi commits
_chezmoi_update_stamp="$XDG_CACHE_HOME/.last_chezmoi_check"
_chezmoi_today=$(date +'%F')
if [ "$(cat "$_chezmoi_update_stamp" 2>/dev/null)" != "$_chezmoi_today" ]; then
    {
        echo "$_chezmoi_today" > "$_chezmoi_update_stamp"
        _src="$(chezmoi source-path 2>/dev/null)"
        if [ -n "$_src" ] && [ -d "$_src/.git" -o -d "$_src/.jj" ]; then
            git -C "$_src" fetch --quiet 2>/dev/null
            _behind=$(git -C "$_src" rev-list --count HEAD..@{u} 2>/dev/null)
            if [ "${_behind:-0}" -gt 0 ]; then
                echo "\033[33m[dotfiles] $_behind upstream commit(s) — run 'chezmoi update' to sync\033[0m"
            fi
        fi
    } &!
fi

# Show motd only when it has changed since last seen
if [[ -f /etc/motd ]]; then
    cmp -s /etc/motd ~/.hushlogin ||
        tee ~/.hushlogin < /etc/motd
fi
