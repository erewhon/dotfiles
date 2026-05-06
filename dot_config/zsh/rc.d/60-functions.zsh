# Tmux session helpers
function mux() {
    tmux new-session -A -s $1
}

function imux() {
    tmux -CC new-session -A -s $1
}

# Sorted diff
function diffs() {
    diff "${@:3}" <(sort "$1") <(sort "$2")
}

function sumcount() {
    sort | uniq -c | sort -n
}

# Decode JWT (and JWE) tokens
function fjwt() {
  for part in 1 2; do
    b64="$(cut -f$part -d. <<< "$1" | tr '_-' '/+')"
    len=${#b64}
    n=$((len % 4))
    if [[ 2 -eq n ]]; then
      b64="${b64}=="
    elif [[ 3 -eq n ]]; then
      b64="${b64}="
    fi
    d="$(openssl enc -base64 -d -A <<< "$b64")"
    python -mjson.tool <<< "$d"
    if [[ 1 -eq part ]] && grep '"enc":' <<< "$d" >/dev/null ; then
        exit 0
    fi
  done
}

# Emoji-Log git helpers — https://github.com/ahmadawais/Emoji-Log
function gcap() {
    git add . && git commit -m "$*" && git push
}
function gnew() { gcap "📦 NEW: $@" }
function gimp() { gcap "👌 IMPROVE: $@" }
function gfix() { gcap "🐛 FIX: $@" }
function grlz() { gcap "🚀 RELEASE: $@" }
function gdoc() { gcap "📖 DOC: $@" }
function gtst() { gcap "✅ TEST: $@" }

# Open PR and auto-merge (after pushing separately)
gpm() {
    local base="${1:-main}"
    gh pr create --fill --base "$base" && \
    gh pr merge --auto --squash --delete-branch
}

# Push, open PR, auto-merge, and clean up branch
gship() {
    local base="${1:-main}"
    git push -u origin HEAD && \
    gh pr create --fill --base "$base" && \
    gh pr merge --auto --squash --delete-branch
}

function autotmux {
    autossh -M 0 -t $1 'tmux -2 attach -d'
}

function append_ssh_key() {
    ssh $1 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
}

# Ring the terminal bell
growl() { echo -e $'\e]9;'${1}'\007' ; return  ; }

doctor() {
  echo Verifying add-on commands
  for cmd in bat delta exa fd fx fzf go http jq fastfetch node npm rlwrap tmux zoxide; do
      echo -ne "\nchecking for ${cmd}... "
      command -v $cmd &> /dev/null || echo -n "missing command '${cmd}'"
  done
  echo -e "\n\nDone"
}

# Fun
function quote() {
    fortune | parrotsay
}

function starwars() {
    nc towel.blinkenlights.nl 23
}

# TypeScript scaffold
function mkts() {
    echo "Initializing new package for Typescript"
    npm init -y
    npm i --save-dev typescript @types/node ts-node nodemon
    npx tsc --init
}

# macOS automation
if [[ "$OSTYPE" == darwin* ]]; then
    function display_notify() {
        /usr/bin/osascript -e "display notification \"$*\""
    }

    function send() {
        osascript -e 'tell application "System Events" to keystroke "'"$*"'"'
        display_notify "sent string" with title "zshrc"
    }

    function send_slow() {
        cat <<EOF | osascript -
        set texttowrite to "$*"
        tell application "System Events"
           repeat with i from 1 to count characters of texttowrite
               keystroke (character i of texttowrite)
               delay 0.04
           end repeat
        end tell
EOF
    }

    function send_slow_file() {
       cat $* | while read line
       do
           send_slow "$line"
           osascript -e 'tell application "System Events" to keystroke return'
       done
    }

    function send_slow_multiline() {
       sleep 5
       while read line
       do
           send_slow "$line"
           osascript -e 'tell application "System Events" to keystroke return'
       done
    }
fi
