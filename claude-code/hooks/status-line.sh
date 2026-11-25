#!/usr/bin/env bash
# Status line (Linux/MacOS): the recommended commit title that practices/commit-title.sh keeps for the
# session's directory, marked when the working state changed since it was written. Prints nothing
# outside a git repo, when no title is stored, or when the title is stale on a clean tree, since
# that title was most likely for work already committed.
#
# Every change here is mirrored in status-line.ps1, and test/status-line-cases.tsv must pass on both.

HOOK_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
COMMIT_TITLE="$HOOK_DIR/../practices/commit-title.sh"

# Prints the status line for one line of commit-title.sh output and the tree state (clean or dirty),
# or nothing.
calc_status_line() {
    local check="$1" tree="$2"
    case "$check" in
        'fresh '*) printf 'commit: %s' "${check#fresh }" ;;
        'stale '*) [[ $tree == clean ]] || printf 'commit (stale): %s' "${check#stale }" ;;
    esac
}

# Prints clean when git sees no staged, unstaged, or untracked change, else dirty.
fetch_tree_state() {
    local porcelain
    porcelain="$(git -C "$1" status --porcelain)"
    if [[ -n $porcelain ]]; then
        printf dirty
        return
    fi
    printf clean
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' not found" >&2; exit 1; }

    local dir check tree=dirty
    dir="$(jq -r '.workspace.current_dir // ""')"
    [[ -n $dir ]] || return 0
    git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1 || return 0
    check="$(bash "$COMMIT_TITLE" --repo "$dir")"
    # Only a stale title reads the tree state, so the common case skips a git call.
    if [[ $check == 'stale '* ]]; then
        tree="$(fetch_tree_state "$dir")"
    fi
    calc_status_line "$check" "$tree"
}

# Sourcing loads the policy without consuming stdin, which is how the tests drive it.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    shopt -s inherit_errexit
    main
fi
