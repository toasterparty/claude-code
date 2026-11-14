#!/usr/bin/env bash
# Asserts agenda-reminder.sh against test/agenda-reminder-cases.tsv and the marker fixture below.
# Run run-agenda-reminder-tests.ps1 for the .ps1 twin.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )

source "$TOP_DIR/claude-code/hooks/agenda-reminder.sh"

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

while IFS=$'\t' read -r expected is_subagent reminded file_path; do
    if [[ -z $expected || $expected == \#* ]]; then
        continue
    fi

    agenda_reminder_decision "${file_path:-}" "$is_subagent" "$reminded"
    check "$expected" "$REMINDER_DECISION" "subagent=$is_subagent reminded=$reminded ${file_path:-<no file path>}"
done < "$SCRIPT_DIR/agenda-reminder-cases.tsv"

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

reminded() {
    if is_reminded "$FIXTURE_DIR/markers" "$1"; then echo 1; else echo 0; fi
}

check 0 "$(reminded session-a)" 'new session is not yet reminded'
save_reminded "$FIXTURE_DIR/markers" session-a
check 1 "$(reminded session-a)" 'session stays reminded once saved'
check 0 "$(reminded session-b)" 'another session is unaffected'
check 1 "$(reminded '')" 'session without an id counts as reminded'
check 1 "$(reminded '../escape')" 'session id that is not a safe file name counts as reminded'
check 1 "$([[ $MARKER_DIR == *-"$UID" ]] && echo 1 || echo 0)" 'each user gets their own marker directory'

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
