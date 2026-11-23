#!/usr/bin/env bash
# Asserts permission-gate.sh against test/gate-cases.tsv. Run run-gate-tests.ps1 for the .ps1 twin.
set -euo pipefail
shopt -s nullglob
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )

source "$TOP_DIR/claude-code/hooks/permission-gate.sh"

total=0
failed=0
while IFS=$'\t' read -r expected command_text; do
    if [[ -z $expected || $expected == \#* ]]; then
        continue
    fi

    total=$((total + 1))
    command_text=${command_text//'<NL>'/$'\n'}
    gate_decision "${command_text:-}"
    if [[ $GATE_DECISION != "$expected" ]]; then
        failed=$((failed + 1))
        printf 'FAIL expected=%s actual=%s : %s\n' "$expected" "$GATE_DECISION" "${command_text:-}"
    fi
done < "$SCRIPT_DIR/gate-cases.tsv"

# The hook end to end: a PreToolUse request on stdin, its decision on stdout.
expect_request() {
    local json="$1" decision="$2" reason="$3" output
    total=$((total + 1))
    output="$(printf '%s' "$json" | bash "$TOP_DIR/claude-code/hooks/permission-gate.sh" |
        jq -r '.hookSpecificOutput | [.hookEventName, .permissionDecision, .permissionDecisionReason] | join("\t")')"
    if [[ $output != "PreToolUse"$'\t'"$decision"$'\t'"$reason" ]]; then
        failed=$((failed + 1))
        printf 'FAIL end to end: %s\n' "$json"
    fi
}
expect_request '{"tool_input":{"command":"sudo ls"}}' deny "$REASON_SUDO"
expect_request '{"tool_input":{}}' allow "$REASON_ALLOW"
expect_request '{}' allow "$REASON_ALLOW"
expect_request '{"tool_name":"Bash","tool_input":{"command":"rm -rf $W"}}' deny "$REASON_RM"
expect_request '{"tool_name":"Bash","tool_input":{"command":"rm -rf ${W:?}/x"}}' allow "$REASON_ALLOW"
expect_request '{"tool_name":"PowerShell","tool_input":{"command":"rm -rf ${W:?}/x"}}' deny "$REASON_RM_POWERSHELL"
expect_request '{"tool_name":"PowerShell","tool_input":{"command":"Remove-Item -Recurse $W"}}' allow "$REASON_ALLOW"

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
