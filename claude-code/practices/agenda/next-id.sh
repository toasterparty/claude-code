#!/usr/bin/env bash
# Allocates the next agenda item IDs for a repo and prints them, one per line.
# IDs are never reused: the next ID follows both the counter (the last ID issued) and the highest
# ID in use, so a hand-written ID or a lost counter cannot cause a collision. An ID is in use where
# it opens an item, sits in a `blocked by` tag, or names a log line. Any other #N, such as another
# project's PR number, is not an ID.
set -euo pipefail
shopt -s nullglob
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/../lock.sh"

usage() {
    echo "Usage: $0 --repo <path> [--count <n>]" >&2
    exit 2
}

list_agenda_ids() {
    awk '
        match($0, /^[ \t]*- #[0-9]+ /) {
            id = substr($0, RSTART, RLENGTH)
            gsub(/[^0-9]/, "", id)
            print id
        }
        {
            rest = $0
            while (match(rest, /`blocked by [^`]*`/)) {
                tag = substr(rest, RSTART, RLENGTH)
                rest = substr(rest, RSTART + RLENGTH)
                while (match(tag, /#[0-9]+/)) {
                    print substr(tag, RSTART + 1, RLENGTH - 1)
                    tag = substr(tag, RSTART + RLENGTH)
                }
            }
        }
    ' "$@"
}

list_logged_ids() {
    awk '/^- / && $2 ~ /^[0-9]+-[0-9]+-[0-9]+$/ && $3 ~ /^#[0-9]+$/ { print substr($3, 2) }' "$@"
}

fetch_max_used_id() {
    local doc_dir=$1
    # [.] turns a fixed name into a glob, so nullglob drops it when the file is missing
    local agenda_files=("$doc_dir"/agenda[.]md "$doc_dir"/agenda/*.md)
    local log_files=("$doc_dir"/agenda-log[.]md)
    local max=0 id
    while read -r id; do
        if ((10#$id > max)); then max=$((10#$id)); fi
    done < <(
        ((${#agenda_files[@]} == 0)) || list_agenda_ids "${agenda_files[@]}"
        ((${#log_files[@]} == 0)) || list_logged_ids "${log_files[@]}"
    )
    echo "$max"
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
[[ -d "$repo" ]] || { echo "Error: --repo '$repo' is not a directory" >&2; exit 2; }
[[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "Error: --count '$count' is not a positive integer" >&2; exit 2; }

bash "$SCRIPT_DIR/../agent-dir/ensure-layout.sh" --repo "$repo" >/dev/null
doc_dir="$repo/.agent/doc"
counter="$doc_dir/agenda-id"
lock_dir="$counter.lock"

take_lock "$lock_dir"
trap 'give_lock "$lock_dir"' EXIT

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
