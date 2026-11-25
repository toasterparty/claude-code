#!/usr/bin/env bash
# Asserts claude-code/practices/agent-dir/ensure-layout.sh against throwaway directories.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )
ENSURE_LAYOUT="$TOP_DIR/claude-code/practices/agent-dir/ensure-layout.sh"

total=0
failed=0

check() {
    local expected="$1" actual="$2" label="$3"
    total=$((total + 1))
    if [[ $actual != "$expected" ]]; then
        failed=$((failed + 1))
        printf 'FAIL expected=%s actual=%s : %s\n' "$expected" "$actual" "$label"
    fi
}

check_exit() {
    local expected="$1" label="$2" actual=0
    shift 2
    bash "$ENSURE_LAYOUT" "$@" >/dev/null 2>&1 || actual=$?
    check "$expected" "$actual" "$label"
}

list_tree() {
    (cd "$1" && find . | LC_ALL=C sort)
}

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

fresh="$FIXTURE_DIR/fresh"
mkdir "$fresh"
check "created $fresh/.agent
created $fresh/.agent/.gitignore
created $fresh/.agent/inbox
created $fresh/.agent/outbox
created $fresh/.agent/reports
created $fresh/.agent/scripts
created $fresh/.agent/doc" "$(bash "$ENSURE_LAYOUT" --repo "$fresh")" 'a fresh repo gets every part, each printed'
check '*' "$(<"$fresh/.agent/.gitignore")" 'the created .gitignore ignores all of .agent'
check '.
./.agent
./.agent/.gitignore
./.agent/doc
./.agent/inbox
./.agent/outbox
./.agent/reports
./.agent/scripts' "$(list_tree "$fresh")" 'a fresh repo gets nothing beyond the layout'

before=$(list_tree "$fresh")
check '' "$(bash "$ENSURE_LAYOUT" --repo "$fresh")" 'a rerun prints nothing'
check "$before" "$(list_tree "$fresh")" 'a rerun changes no path'

custom="$FIXTURE_DIR/custom"
mkdir -p "$custom/.agent"
printf '*.log\n' > "$custom/.agent/.gitignore"
check "created $custom/.agent/inbox
created $custom/.agent/outbox
created $custom/.agent/reports
created $custom/.agent/scripts
created $custom/.agent/doc" "$(bash "$ENSURE_LAYOUT" --repo "$custom")" 'an existing .agent gets only the missing dirs'
check '*.log' "$(<"$custom/.agent/.gitignore")" 'an existing .gitignore with other content is left as it is'

partial="$FIXTURE_DIR/partial"
mkdir -p "$partial/.agent/inbox"
printf '*\n' > "$partial/.agent/.gitignore"
printf 'plan\n' > "$partial/.agent/inbox/plan.md"
bash "$ENSURE_LAYOUT" --repo "$partial" >/dev/null
check 'plan' "$(<"$partial/.agent/inbox/plan.md")" 'a file the user left in inbox is untouched'
check './plan.md' "$(cd "$partial/.agent/inbox" && find . -mindepth 1)" 'nothing is added inside an existing inbox'

check_exit 2 'a missing --repo is rejected'
check_exit 2 'a --repo with no value is rejected' --repo
check_exit 2 'a --repo that is not a directory is rejected' --repo "$FIXTURE_DIR/absent"
check_exit 2 'an unknown argument is rejected' --repo "$fresh" --bogus
check 'false' "$([[ -e "$FIXTURE_DIR/absent" ]] && echo true || echo false)" 'a rejected --repo creates nothing'

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
