# Terminal / color hints.
#
# SSH strips COLORTERM, so apps on the remote (vim, nvim, tmux, fzf, bat)
# fall back to 256 colors even though the local terminal does truecolor.
# Every terminal I use locally (Ghostty, Alacritty, Kitty, iTerm2, WezTerm)
# supports truecolor, so when we're in an SSH session with no COLORTERM,
# assume the upstream emulator can handle it.
if [[ -z "$COLORTERM" ]] && [[ -n "$SSH_CONNECTION" || -n "$SSH_TTY" ]]; then
    export COLORTERM=truecolor
fi
