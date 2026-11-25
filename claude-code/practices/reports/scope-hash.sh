#!/usr/bin/env bash
# Prints one hash of the content of every file under the given repo-relative paths, tracked or
# untracked but not ignored, so a later run can tell whether a report's scope has changed since.
# The hash changes when a file under the paths is edited, added, removed, or renamed.
set -euo pipefail

usage() {
    echo "Usage: $0 --repo <path> <path>..." >&2
    exit 2
}

# -z keeps git from quoting unusual names. A tracked file deleted from the working tree is skipped,
# so its deletion changes the list rather than failing the hash.
list_files() {
    local repo=$1 listing path
    shift
    listing=$(git -C "$repo" ls-files -z -co --exclude-standard -- "$@" | tr '\0' '\n' | LC_ALL=C sort -u)
    while IFS= read -r path; do
        if [[ -n "$path" && -f "$repo/$path" ]]; then printf '%s\n' "$path"; fi
    done <<< "$listing"
}

repo=""
paths=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) [[ $# -ge 2 ]] || usage; repo=$2; shift 2 ;;
        --) shift; paths+=("$@"); break ;;
        -*) echo "Error: unknown argument '$1'" >&2; usage ;;
        *) paths+=("$1"); shift ;;
    esac
done
[[ -n "$repo" && ${#paths[@]} -gt 0 ]] || usage
[[ -d "$repo" ]] || { echo "Error: --repo '$repo' is not a directory" >&2; exit 2; }
for path in "${paths[@]}"; do
    [[ -e "$repo/$path" ]] || { echo "Error: '$path' not found in '$repo'" >&2; exit 2; }
done

files=$(list_files "$repo" "${paths[@]}")
if [[ -z "$files" ]]; then
    git hash-object --stdin < /dev/null
    exit
fi
hashes=$(git -C "$repo" hash-object --stdin-paths <<< "$files")
paste -d ' ' <(printf '%s\n' "$hashes") <(printf '%s\n' "$files") | git hash-object --stdin
