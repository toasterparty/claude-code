#!/usr/bin/env bash
# Creates whichever parts of the <repo>/.agent/ layout are missing - the dir, its .gitignore holding
# the single line *, and the five layout dirs - and prints "created <path>" for each. An existing
# .gitignore is left as it is. Never writes inside inbox/: it only creates the empty dir.
# Agents run this instead of their own mkdir because the Edit(**/.agent/inbox/**) deny also blocks a
# shell command naming inbox/ as its target, while a mkdir inside a script passes.
set -euo pipefail

LAYOUT_DIRS=(inbox outbox reports scripts doc)

usage() {
    echo "Usage: $0 --repo <path>" >&2
    exit 2
}

ensure_dir() {
    local path=$1
    [[ -d "$path" ]] && return
    mkdir -p "$path"
    echo "created $path"
}

ensure_gitignore() {
    local path=$1
    [[ -e "$path" ]] && return
    printf '*\n' > "$path"
    echo "created $path"
}

repo=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) [[ $# -ge 2 ]] || usage; repo=$2; shift 2 ;;
        *) echo "Error: unknown argument '$1'" >&2; usage ;;
    esac
done
[[ -n "$repo" ]] || usage
[[ -d "$repo" ]] || { echo "Error: --repo '$repo' is not a directory" >&2; exit 2; }

agent_dir="$repo/.agent"
ensure_dir "$agent_dir"
ensure_gitignore "$agent_dir/.gitignore"
for dir in "${LAYOUT_DIRS[@]}"; do
    ensure_dir "$agent_dir/$dir"
done
