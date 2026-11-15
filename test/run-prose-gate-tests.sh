#!/usr/bin/env bash
# Asserts prose-gate.sh against test/prose-gate-cases.tsv and the transcript fixtures below.
# Run run-prose-gate-tests.ps1 for the .ps1 twin.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )

source "$TOP_DIR/claude-code/hooks/prose-gate.sh"

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

while IFS=$'\t' read -r expected in_context file_path; do
    if [[ -z $expected || $expected == \#* ]]; then
        continue
    fi

    prose_gate_decision "${file_path:-}" "$in_context"
    check "$expected" "$GATE_DECISION" "in_context=$in_context ${file_path:-<no file_path>}"
done < "$SCRIPT_DIR/prose-gate-cases.tsv"

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

cat >"$FIXTURE_DIR/read.jsonl" <<'EOF'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"C:\\Users\\x\\.claude\\languages\\english.md"}}]}}
EOF

# The name appears in prose and as a search target, neither of which puts the content in context.
cat >"$FIXTURE_DIR/mention.jsonl" <<'EOF'
{"type":"user","message":{"content":"did you read english.md for the report you made?"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/repo/src/main.c"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Grep","input":{"path":"/repo/languages","pattern":"english.md"}}]}}
EOF

english_text="$(cat -- "$ENGLISH_PATH")"
sentinel="$(english_sentinel "$english_text")"

# A shell read leaves the file's text in a tool_result, never a file_path.
jq -cn --arg text "$english_text" \
    '{type: "user", message: {content: [{type: "tool_result", content: $text}]}}' >"$FIXTURE_DIR/cat.jsonl"
jq -cn --arg text "PreToolUse:Write hook error: $(build_denial_reason "$english_text")" \
    '{type: "user", message: {content: [{type: "tool_result", content: $text}]}}' >"$FIXTURE_DIR/denial.jsonl"

in_context() {
    if english_md_in_context "$1" "$2"; then echo 1; else echo 0; fi
}

check 1 "$([[ ${#sentinel} -ge 40 ]] && echo 1 || echo 0)" 'sentinel is a distinctive line of english.md'
check 1 "$(in_context "$FIXTURE_DIR/read.jsonl" "$sentinel")" 'transcript holding a read of english.md'
check 1 "$(in_context "$FIXTURE_DIR/cat.jsonl" "$sentinel")" 'transcript holding english.md read through a shell'
check 1 "$(in_context "$FIXTURE_DIR/denial.jsonl" "$sentinel")" 'transcript holding an earlier denial'
check 0 "$(in_context "$FIXTURE_DIR/mention.jsonl" "$sentinel")" 'transcript that only names english.md'
check 0 "$(in_context "$FIXTURE_DIR/mention.jsonl" '')" 'missing english.md leaves no empty sentinel matching everything'
check 1 "$(in_context "$FIXTURE_DIR/absent.jsonl" "$sentinel")" 'unreadable transcript fails open'
check "$REASON_UNREAD" "$(build_denial_reason '')" 'missing english.md falls back to asking for a read'

denial="$(jq -cn --arg file_path /repo/README.md --arg transcript "$FIXTURE_DIR/mention.jsonl" \
    '{tool_input: {file_path: $file_path}, transcript_path: $transcript}' \
    | bash "$TOP_DIR/claude-code/hooks/prose-gate.sh" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
check 1 "$([[ $denial == *"$sentinel"* ]] && echo 1 || echo 0)" 'hook denial is valid JSON carrying english.md'

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
