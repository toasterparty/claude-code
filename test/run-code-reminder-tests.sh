#!/usr/bin/env bash
# Asserts code-reminder.sh against test/code-reminder-cases.tsv and the fixtures below.
# Run run-code-reminder-tests.ps1 for the .ps1 twin.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )
HOOK="$TOP_DIR/claude-code/hooks/code-reminder.sh"

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

while IFS=$'\t' read -r expected reminded in_context file_path; do
    if [[ -z $expected || $expected == \#* ]]; then
        continue
    fi

    code_reminder_decision "${file_path:-}" "$reminded" "$in_context"
    check "$expected" "$REMINDER_DECISION" "reminded=$reminded in_context=$in_context ${file_path:-<no file path>}"
done < "$SCRIPT_DIR/code-reminder-cases.tsv"

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

check session-a "$(build_marker_name session-a '')" 'top-level session is marked by its id'
check session-a-sub "$(build_marker_name session-a sub)" 'subagent is marked apart from its parent'
check 1 "$(is_reminded "$FIXTURE_DIR/markers" '' && echo 1 || echo 0)" 'context without an id counts as reminded'

# The hook end to end: a PostToolUse request on stdin, the reminder or nothing on stdout.
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/home/u/.claude/languages/common.md"}}]}}' > "$FIXTURE_DIR/read.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/repo/README.md"}}]}}' > "$FIXTURE_DIR/unread.jsonl"
printf '{"type":"user","message":{"content":"%s"}}\n' "$(common_sentinel)" > "$FIXTURE_DIR/text.jsonl"
mkdir -p "$FIXTURE_DIR/unread/subagents"
cp "$FIXTURE_DIR/read.jsonl" "$FIXTURE_DIR/unread/subagents/agent-sub.jsonl"

expect_request() {
    local json="$1" expected="$2" label="$3" output actual=silent
    output="$(printf '%s' "$json" | TMPDIR="$FIXTURE_DIR" bash "$HOOK")"
    if [[ -n $output ]]; then
        [[ $(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext') == "$REMINDER" ]] && actual=remind || actual=garbled
    fi
    check "$expected" "$actual" "end to end: $label"
}
unread="$FIXTURE_DIR/unread.jsonl"
read_done="$FIXTURE_DIR/read.jsonl"
expect_request '{"session_id":"e2e-a","transcript_path":"'"$unread"'","tool_input":{"file_path":"/repo/src/main.c"}}' remind 'first code edit with common.md unread reminds'
expect_request '{"session_id":"e2e-a","transcript_path":"'"$unread"'","tool_input":{"file_path":"/repo/src/other.c"}}' silent 'second code edit is silent'
expect_request '{"session_id":"e2e-b","transcript_path":"'"$read_done"'","tool_input":{"file_path":"/repo/src/main.c"}}' silent 'code edit with common.md read is silent'
expect_request '{"session_id":"e2e-e","transcript_path":"'"$FIXTURE_DIR/text.jsonl"'","tool_input":{"file_path":"/repo/src/main.c"}}' silent 'code edit with common.md text in context is silent'
expect_request '{"session_id":"e2e-c","transcript_path":"'"$unread"'","agent_id":"sub","tool_input":{"file_path":"/repo/src/main.c"}}' silent 'subagent that read common.md is silent'
expect_request '{"session_id":"e2e-c","transcript_path":"'"$unread"'","tool_input":{"file_path":"/repo/README.md"}}' silent 'prose edit is silent'
expect_request '{"session_id":"e2e-d","transcript_path":"'"$FIXTURE_DIR/missing.jsonl"'","tool_input":{"file_path":"/repo/src/main.c"}}' silent 'unreadable transcript is silent'

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
