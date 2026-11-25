#!/usr/bin/env bash
# Asserts claude-code/practices/reports/new-report.sh and scope-hash.sh against throwaway repos.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )
NEW_REPORT="$TOP_DIR/claude-code/practices/reports/new-report.sh"
SCOPE_HASH="$TOP_DIR/claude-code/practices/reports/scope-hash.sh"
TODAY=$(date +%F)
DAY=${TODAY//-/}

total=0
failed=0

check() {
    local expected="$1" actual="$2" label="$3"
    total=$((total + 1))
    if [[ $actual != "$expected" ]]; then
        failed=$((failed + 1))
        printf 'FAIL : %s\n--- expected\n%s\n--- actual\n%s\n' "$label" "$expected" "$actual"
    fi
}

check_exit() {
    local expected="$1" label="$2" script="$3" actual=0
    shift 3
    bash "$script" "$@" >/dev/null 2>&1 || actual=$?
    check "$expected" "$actual" "$label"
}

check_differs() {
    local before="$1" after="$2" label="$3"
    total=$((total + 1))
    if [[ $before == "$after" ]]; then
        failed=$((failed + 1))
        printf 'FAIL : %s\n--- both\n%s\n' "$label" "$before"
    fi
}

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

git_in() {
    git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false -c core.autocrlf=false "${@:2}"
}

new_git_repo() {
    local repo
    repo=$(mktemp -d "$FIXTURE_DIR/repo.XXXXXX")
    git init -q -b main "$repo"
    mkdir -p "$repo/src/hud" "$repo/.agent"
    printf '*\n' > "$repo/.agent/.gitignore"
    printf 'build/\n' > "$repo/.gitignore"
    printf 'a\n' > "$repo/src/hud/a.txt"
    printf 'b\n' > "$repo/src/pause.txt"
    printf 'readme\n' > "$repo/README.md"
    git_in "$repo" add -A
    git_in "$repo" commit -q -m init
    echo "$repo"
}

# new-report.sh

repo=$(new_git_repo)
sha=$(git -C "$repo" rev-parse --short HEAD)
path=$(bash "$NEW_REPORT" --repo "$repo" --skill refine)
check "$repo/.agent/reports/${DAY}a-refine.md" "$path" 'the first report of the day takes sequence a'
check "---
skill: refine
date: $TODAY
branch: main
commit: $sha
---" "$(<"$path")" 'the front matter carries the fields the script can supply'
check "$repo/.agent/reports/${DAY}b-consult-agenda-ids.md" \
    "$(bash "$NEW_REPORT" --repo "$repo" --skill consult --subject agenda-ids)" \
    'the next report takes sequence b, whatever its skill, and names its subject'
check 'subject: agenda-ids' "$(grep '^subject:' "$repo/.agent/reports/${DAY}b-consult-agenda-ids.md")" \
    'a subject is written to the front matter'

printf 'edit\n' >> "$repo/README.md"
path=$(bash "$NEW_REPORT" --repo "$repo" --skill next)
check "commit: $sha-dirty" "$(grep '^commit:' "$path")" 'an uncommitted tracked change marks the commit dirty'

repo=$(new_git_repo)
mkdir -p "$repo/.agent/reports/_archive"
for seq in {a..x}; do : > "$repo/.agent/reports/$DAY$seq-next.md"; done
: > "$repo/.agent/reports/_archive/${DAY}y-refine.md"
check "$repo/.agent/reports/${DAY}za-next.md" "$(bash "$NEW_REPORT" --repo "$repo" --skill next)" \
    'the sequence after y is za, counting archived reports as taken'
: > "$repo/.agent/reports/${DAY}zb-next.md"
check "$repo/.agent/reports/${DAY}zc-next.md" "$(bash "$NEW_REPORT" --repo "$repo" --skill next)" \
    'a taken z sequence is skipped'

repo=$(new_git_repo)
mkdir -p "$repo/.agent/reports/.new-report.lock"
touch -d "@$(( $(date +%s) - 120 ))" "$repo/.agent/reports/.new-report.lock"
check "$repo/.agent/reports/${DAY}a-next.md" "$(bash "$NEW_REPORT" --repo "$repo" --skill next 2>&1)" \
    'a lock older than a minute is broken'
check 'gone' "$([[ -e "$repo/.agent/reports/.new-report.lock" ]] && echo held || echo gone)" 'the lock is given back on exit'

repo=$(mktemp -d "$FIXTURE_DIR/unborn.XXXXXX")
git init -q -b main "$repo"
path=$(bash "$NEW_REPORT" --repo "$repo" --skill consult)
check "---
skill: consult
date: $TODAY
branch: main
---" "$(<"$path")" 'a repo with no commit yet leaves the commit out'
check '*' "$(<"$repo/.agent/.gitignore")" 'a missing .agent/ is created ignoring itself'

check_exit 2 'a --repo that is not a directory is rejected' "$NEW_REPORT" --repo "$FIXTURE_DIR/missing" --skill next
check_exit 2 'a skill that is not a lowercase slug is rejected' "$NEW_REPORT" --repo "$repo" --skill Refine
check_exit 2 'a subject with an underscore is rejected' "$NEW_REPORT" --repo "$repo" --skill refine --subject hud_blending
check_exit 2 'a missing skill is rejected' "$NEW_REPORT" --repo "$repo"
check_exit 2 'an unknown argument is rejected' "$NEW_REPORT" --repo "$repo" --skill next --bogus

# scope-hash.sh

repo=$(new_git_repo)
scope_hash() { bash "$SCOPE_HASH" --repo "$repo" "$@"; }
# The blob hash of "a\n", then of "b\n", each with its path, one line each, hashed as one blob
check 'ae17b34c530b39545cd61b5362599b5bacbe12c5' "$(scope_hash src/hud/ src/pause.txt)" \
    'the hash covers each file blob and path under the scope'
check "$(scope_hash src/hud/ src/pause.txt)" "$(scope_hash src/pause.txt src/hud/)" 'the order of the paths does not matter'

base=$(scope_hash src/)
printf 'outside\n' >> "$repo/README.md"
check "$base" "$(scope_hash src/)" 'an edit outside the scope leaves the hash'
mkdir -p "$repo/src/build"
printf 'artifact\n' > "$repo/src/build/out.o"
check "$base" "$(scope_hash src/)" 'an ignored file leaves the hash'

printf 'a2\n' > "$repo/src/hud/a.txt"
check_differs "$base" "$(scope_hash src/)" 'editing a tracked file changes the hash'
printf 'a\n' > "$repo/src/hud/a.txt"
check "$base" "$(scope_hash src/)" 'restoring the content restores the hash'

printf 'new\n' > "$repo/src/hud/new.txt"
check_differs "$base" "$(scope_hash src/)" 'adding an untracked file changes the hash'
rm -f "$repo/src/hud/new.txt"

mv "$repo/src/pause.txt" "$repo/src/paused.txt"
check_differs "$base" "$(scope_hash src/)" 'renaming a file changes the hash'
rm -f "$repo/src/paused.txt"
check_differs "$base" "$(scope_hash src/)" 'deleting a tracked file changes the hash without failing'

check_exit 2 'a scope path that does not exist is rejected' "$SCOPE_HASH" --repo "$repo" src/ src/gone.rs
check_exit 2 'a --repo that is not a directory is rejected' "$SCOPE_HASH" --repo "$FIXTURE_DIR/missing" src/
check_exit 2 'no scope path is rejected' "$SCOPE_HASH" --repo "$repo"
check_exit 2 'an unknown argument is rejected' "$SCOPE_HASH" --repo "$repo" --bogus src/

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
