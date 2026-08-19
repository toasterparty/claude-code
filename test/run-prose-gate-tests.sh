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

in_context() {
    if english_md_in_context "$1"; then echo 1; else echo 0; fi
}

check 1 "$(in_context "$FIXTURE_DIR/read.jsonl")" 'transcript holding a read of english.md'
check 0 "$(in_context "$FIXTURE_DIR/mention.jsonl")" 'transcript that only names english.md'
check 1 "$(in_context "$FIXTURE_DIR/absent.jsonl")" 'unreadable transcript fails open'

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
