#!/usr/bin/env bash
# Claude Code Stop hook: post the turn's journal entry to the inbox.
#
# Reads the hook JSON on stdin (session_id, cwd), resolves the tmux pane the
# session lives in, and hands the last entry of today's journal to
# `inbox from-journal`, which dedupes by entry fingerprint, so a turn that
# did not journal posts nothing. Always exits 0; the hook must never hold a
# session up.
#
# Install: copy to ~/.claude/hooks/inbox-stop.sh and add to settings.json:
#   "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/inbox-stop.sh" }] }]
set -u
export PATH="$HOME/.local/bin:$PATH"
input=$(cat 2>/dev/null || true)
command -v inbox >/dev/null 2>&1 || exit 0
# Foreman workers journal too, but the foreman posts their entries itself (with goal/task refs).
[ -n "${FOREMAN_WORKER:-}" ] && exit 0
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd="$PWD"
target=$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)
args=(from-journal -C "$cwd")
[ -n "$session_id" ] && args+=(--session-id "$session_id")
[ -n "$target" ] && args+=(--tmux-target "$target")
log="${XDG_STATE_HOME:-$HOME/.local/state}/inbox"
mkdir -p "$log" 2>/dev/null
( inbox "${args[@]}" >>"$log/hook.log" 2>&1 ) &
exit 0
