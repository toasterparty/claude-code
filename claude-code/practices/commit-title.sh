#!/usr/bin/env bash
# Keeps a repo's recommended commit title in <repo>/.agent/commit-title.txt: line 1 the title, line 2
# a hash of the working state it was written for (HEAD, branch, the diff against HEAD, and untracked
# files). With --title, writes the file. Without, prints "fresh <title>" or "stale <title>", or
# nothing when no title is stored. A commit, ref switch, stash, or edit since the write makes it stale.
set -euo pipefail

MAX_TITLE_LEN=72

usage() {
    echo "Usage: $0 --repo <path> [--title <text>]" >&2
    exit 2
}

fetch_state_hash() {
    local top=$1 base
    # An unborn HEAD diffs against the empty tree, so a fresh repo still hashes
    base=$(git -C "$top" rev-parse -q --verify HEAD || git -C "$top" hash-object -t tree /dev/null)
    {
        echo "$base"
        git -C "$top" branch --show-current
        git -C "$top" -c core.safecrlf=false diff "$base" --binary
        git -C "$top" ls-files -o --exclude-standard -z
        git -C "$top" ls-files -o --exclude-standard -z | xargs -0 -r git -C "$top" hash-object --
    } | git hash-object --stdin
}

ensure_agent_dir() {
    local agent_dir=$1
    [[ -d "$agent_dir" ]] && return
    mkdir -p "$agent_dir"
    printf '*\n' > "$agent_dir/.gitignore"
}

write_title() {
    local top=$1 title=$2 title_file=$3
    [[ -n "$title" ]] || { echo "Error: --title is empty" >&2; exit 2; }
    [[ "$title" != *$'\n'* ]] || { echo "Error: --title spans more than one line" >&2; exit 2; }
    ((${#title} <= MAX_TITLE_LEN)) || { echo "Error: --title is ${#title} characters, over $MAX_TITLE_LEN" >&2; exit 2; }
    ensure_agent_dir "$top/.agent"
    printf '%s\n%s\n' "$title" "$(fetch_state_hash "$top")" > "$title_file.tmp"
    mv -f "$title_file.tmp" "$title_file"
}

check_title() {
    local top=$1 title_file=$2 title stored_hash
    [[ -f "$title_file" ]] || return 0
    { read -r title; read -r stored_hash; } < "$title_file"
    if [[ "$stored_hash" == "$(fetch_state_hash "$top")" ]]; then
        echo "fresh $title"
    else
        echo "stale $title"
    fi
}

repo=""
title=""
has_title=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) [[ $# -ge 2 ]] || usage; repo=$2; shift 2 ;;
        --title) [[ $# -ge 2 ]] || usage; title=$2; has_title=1; shift 2 ;;
        *) echo "Error: unknown argument '$1'" >&2; usage ;;
    esac
done
[[ -n "$repo" ]] || usage

top=$(git -C "$repo" rev-parse --show-toplevel)
title_file="$top/.agent/commit-title.txt"
if ((has_title)); then
    write_title "$top" "$title" "$title_file"
else
    check_title "$top" "$title_file"
fi
