#!/usr/bin/env bash
# Asserts claude-code/practices/commit-title.sh against throwaway repos. A commit or ref switch also
# makes a title stale, but asserting it would need a git write, so those cases go untested.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )
COMMIT_TITLE="$TOP_DIR/claude-code/practices/commit-title.sh"

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

check_status() {
    check "$1" "$(bash "$COMMIT_TITLE" --repo "$2")" "$3"
}

check_exit() {
    local expected="$1" label="$2" actual=0
    shift 2
    bash "$COMMIT_TITLE" "$@" 2>/dev/null || actual=$?
    check "$expected" "$actual" "$label"
}

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

clone="$FIXTURE_DIR/clone"
git clone -q "$TOP_DIR" "$clone"
check_status '' "$clone" 'no stored title prints nothing'

bash "$COMMIT_TITLE" --repo "$clone" --title 'Fix the thing'
check_status 'fresh Fix the thing' "$clone" 'title is fresh right after writing'
check '*' "$(<"$clone/.agent/.gitignore")" 'writing creates .agent ignoring itself'
check_status 'fresh Fix the thing' "$clone/test" 'a subdirectory reads the repo root title'

printf 'edit\n' >> "$clone/README.md"
check_status 'stale Fix the thing' "$clone" 'editing a tracked file makes it stale'

bash "$COMMIT_TITLE" --repo "$clone" --title 'Fix the thing and the README'
check_status 'fresh Fix the thing and the README' "$clone" 'rewriting makes it fresh again'

printf 'new\n' > "$clone/untracked.txt"
check_status 'stale Fix the thing and the README' "$clone" 'adding an untracked file makes it stale'

bash "$COMMIT_TITLE" --repo "$clone" --title 'Add untracked.txt'
printf 'changed\n' > "$clone/untracked.txt"
check_status 'stale Add untracked.txt' "$clone" 'editing an untracked file makes it stale'

bash "$COMMIT_TITLE" --repo "$clone" --title 'Add untracked.txt'
printf 'scratch\n' > "$clone/.agent/notes.md"
check_status 'fresh Add untracked.txt' "$clone" 'a file under .agent leaves it fresh'

git init -q "$clone/nested"
printf 'later\n' > "$clone/zz.txt"
bash "$COMMIT_TITLE" --repo "$clone" --title 'Add zz.txt' 2>/dev/null
printf 'changed\n' > "$clone/zz.txt"
check_status 'stale Add zz.txt' "$clone" 'an untracked nested repo still lets later untracked edits make it stale'

with_external_diff=(env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.external GIT_CONFIG_VALUE_0=false)
"${with_external_diff[@]}" bash "$COMMIT_TITLE" --repo "$clone" --title 'Edit the README' 2>/dev/null
printf 'edit\n' >> "$clone/README.md"
check 'stale Edit the README' "$("${with_external_diff[@]}" bash "$COMMIT_TITLE" --repo "$clone" 2>/dev/null)" \
    'a configured external diff tool still lets tracked edits make it stale'

unborn="$FIXTURE_DIR/unborn"
git init -q "$unborn"
printf 'first\n' > "$unborn/a.txt"
bash "$COMMIT_TITLE" --repo "$unborn" --title 'Add a.txt'
check_status 'fresh Add a.txt' "$unborn" 'a repo with no commits hashes'

check_exit 2 'an empty title is rejected' --repo "$clone" --title ''
check_exit 2 'a two-line title is rejected' --repo "$clone" --title $'One\nTwo'
check_exit 2 'a title with a leading space is rejected' --repo "$clone" --title ' Fix it'
check_exit 2 'a title with a trailing space is rejected' --repo "$clone" --title 'Fix it '
check_exit 2 'a 73-character title is rejected' --repo "$clone" --title "$(printf 'x%.0s' {1..73})"
check_exit 0 'a 72-character title is accepted' --repo "$clone" --title "$(printf 'x%.0s' {1..72})"
check_exit 2 'an unknown argument is rejected' --repo "$clone" --bogus

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
