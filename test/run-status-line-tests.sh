#!/usr/bin/env bash
# Asserts status-line.sh against test/status-line-cases.tsv and the fixtures below.
# Run run-status-line-tests.ps1 for the .ps1 twin.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )
HOOK="$TOP_DIR/claude-code/hooks/status-line.sh"
COMMIT_TITLE="$TOP_DIR/claude-code/practices/commit-title.sh"

source "$HOOK"

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

dash_to_empty() {
    [[ $1 == - ]] || printf '%s' "$1"
}

while IFS=$'\t' read -r check_line tree expected; do
    if [[ -z $check_line || $check_line == \#* ]]; then
        continue
    fi

    check "$(dash_to_empty "$expected")" "$(calc_status_line "$(dash_to_empty "$check_line")" "$tree")" \
        "commit-title.sh printed '$check_line' on a $tree tree"
done < "$SCRIPT_DIR/status-line-cases.tsv"

# The status line end to end: Claude Code's status JSON on stdin, the line or nothing on stdout.
# The ceiling keeps the fixture's non-repo directory from finding a repo above the temp dir.
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT
export GIT_CEILING_DIRECTORIES="$FIXTURE_DIR"
repo="$FIXTURE_DIR/repo"
git init -q "$repo"
mkdir -p "$repo/sub" "$FIXTURE_DIR/plain"
printf 'first\n' > "$repo/a.txt"

expect_line() {
    local expected="$1" request="$2" label="$3" actual status=0
    actual="$(printf '%s' "$request" | bash "$HOOK")" || status=$?
    ((status == 0)) || actual="exit $status"
    check "$expected" "$actual" "end to end: $label"
}

request_for() {
    jq -cn --arg dir "$1" '{cwd: $dir, workspace: {current_dir: $dir, project_dir: $dir}}'
}

expect_line '' "$(request_for "$repo")" 'a repo with no stored title shows nothing'
bash "$COMMIT_TITLE" --repo "$repo" --title 'Add a.txt'
expect_line 'Add a.txt' "$(request_for "$repo")" 'a title written for this state shows'
expect_line 'Add a.txt' "$(request_for "$repo/sub")" 'a subdirectory shows the repo root title'
printf 'edit\n' >> "$repo/a.txt"
expect_line '(stale) Add a.txt' "$(request_for "$repo")" 'an edit since the title was written marks it stale'
# Deleting the repo's only file stands in for a commit, which would need a git write.
rm "$repo/a.txt"
expect_line '' "$(request_for "$repo")" 'a stale title on a clean tree shows nothing'
expect_line '' "$(request_for "$FIXTURE_DIR/plain")" 'a directory outside any repo shows nothing'
expect_line '' '{"model":{"display_name":"Opus"}}' 'a request without a workspace shows nothing'

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
