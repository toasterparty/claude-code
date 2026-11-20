#!/usr/bin/env bash
# Allocates the next agenda item IDs for a repo and prints them, one per line.
# IDs are never reused: the next ID follows both the counter (the last ID issued) and the highest
# #N in the agenda and its log, so a hand-written ID or a lost counter cannot cause a collision.
set -euo pipefail
shopt -s nullglob

LOCK_WAIT_TENTHS=50

usage() {
    echo "Usage: $0 --repo <path> [--count <n>]" >&2
    exit 2
}

fetch_max_used_id() {
    local doc_dir=$1
    # [.] turns a fixed name into a glob, so nullglob drops it when the file is missing
    local files=("$doc_dir"/agenda[.]md "$doc_dir"/agenda/*.md "$doc_dir"/agenda-log[.]md)
    local max=0 id
    ((${#files[@]})) || { echo "$max"; return; }
    while read -r id; do
        if ((10#$id > max)); then max=$((10#$id)); fi
    done < <(grep -ohE '#[0-9]+\b' "${files[@]}" | tr -d '#')
    echo "$max"
}

take_lock() {
    local lock_dir=$1 i
    for ((i = 0; i < LOCK_WAIT_TENTHS; i++)); do
        mkdir "$lock_dir" 2>/dev/null && return
        sleep 0.1
    done
    echo "Error: lock '$lock_dir' still held after $((LOCK_WAIT_TENTHS / 10))s" >&2
    exit 1
}

repo=""
count=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) [[ $# -ge 2 ]] || usage; repo=$2; shift 2 ;;
        --count) [[ $# -ge 2 ]] || usage; count=$2; shift 2 ;;
        *) echo "Error: unknown argument '$1'" >&2; usage ;;
    esac
done
[[ -n "$repo" ]] || usage
[[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "Error: --count '$count' is not a positive integer" >&2; exit 2; }

doc_dir="$repo/.agent/doc"
mkdir -p "$doc_dir"
counter="$doc_dir/agenda-id"
lock_dir="$counter.lock"

take_lock "$lock_dir"
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

last=$(fetch_max_used_id "$doc_dir")
if [[ -f "$counter" ]]; then
    recorded=$(<"$counter")
    [[ "$recorded" =~ ^[0-9]+$ ]] || { echo "Error: '$counter' holds '$recorded', not an integer" >&2; exit 1; }
    if ((recorded > last)); then last=$recorded; fi
fi

next=$((last + count))
printf '%s\n' "$next" > "$counter.tmp"
mv -f "$counter.tmp" "$counter"
seq $((last + 1)) "$next"
