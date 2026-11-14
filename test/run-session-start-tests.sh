#!/usr/bin/env bash
# Asserts session-start.sh against test/session-start-cases.tsv and the fixtures below.
# Run run-session-start-tests.ps1 for the .ps1 twin.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )

source "$TOP_DIR/claude-code/hooks/session-start.sh"

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

while IFS=$'\t' read -r deployed latest expected; do
    if [[ -z $deployed || $deployed == \#* ]]; then
        continue
    fi

    check "$(dash_to_empty "$expected")" \
        "$(calc_drift_message "$(dash_to_empty "$deployed")" "$(dash_to_empty "$latest")")" \
        "deployed=$deployed latest=$latest"
done < "$SCRIPT_DIR/session-start-cases.tsv"

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT
mkdir -p "$FIXTURE_DIR/with/.agent" "$FIXTURE_DIR/without"
printf 'memory\n' > "$FIXTURE_DIR/with/.agent/AGENTS.md"

check "$FIXTURE_DIR/with/.agent/AGENTS.md" "$(find_project_memory "$FIXTURE_DIR/with")" 'directory holding .agent/AGENTS.md'
check '' "$(find_project_memory "$FIXTURE_DIR/without")" 'directory without .agent/AGENTS.md'

for source in startup clear compact; do
    check 1 "$([[ $source =~ $MEMORY_SOURCES ]] && echo 1 || echo 0)" "memory loads on $source"
done
check 0 "$([[ resume =~ $MEMORY_SOURCES ]] && echo 1 || echo 0)" 'memory skips resume'
check 1 "$([[ startup =~ $DRIFT_SOURCES ]] && echo 1 || echo 0)" 'drift checks on startup'
for source in resume clear compact; do
    check 0 "$([[ $source =~ $DRIFT_SOURCES ]] && echo 1 || echo 0)" "drift skips $source"
done

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
