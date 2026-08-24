#!/usr/bin/env bash
# Deny a prose write until english.md is in context. The instruction to read it is a precondition
# on a category the model has to classify for itself while it is busy
# composing, which it misses often enough to need enforcing here. A denial is self-healing: the
# model reads the file and retries, so the cost is one blocked call per session.

PROSE_PATH_PATTERN='(\.md$|(^|/)\.agent/outbox/)'
ENGLISH_READ_PATTERN='"file_path":"[^"]*english\.md"'

REASON_UNREAD='Read languages/english.md (beside CLAUDE.md in the Claude home directory) before writing prose that outlives the session, then retry this write.'

prose_gate_decision() {
    local file_path="$1" english_in_context="$2"

    GATE_DECISION=allow
    if [[ $english_in_context -eq 1 ]]; then
        return
    fi

    local normalized="${file_path//\\//}"
    if printf '%s' "$normalized" | grep -Eqi "$PROSE_PATH_PATTERN"; then
        GATE_DECISION=deny
    fi
}

english_md_in_context() {
    local transcript="$1"

    [[ -f $transcript ]] || return 0
    grep -Eq "$ENGLISH_READ_PATTERN" "$transcript"
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' not found" >&2; exit 1; }

    local request file_path transcript english_in_context=0
    request="$(cat)"
    file_path="$(printf '%s' "$request" | jq -r '.tool_input.file_path // ""')"
    transcript="$(printf '%s' "$request" | jq -r '.transcript_path // ""')"
    if english_md_in_context "$transcript"; then
        english_in_context=1
    fi

    prose_gate_decision "$file_path" "$english_in_context"
    if [[ $GATE_DECISION == deny ]]; then
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' \
            "$REASON_UNREAD"
    fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main
fi
