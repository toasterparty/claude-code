#!/usr/bin/env bash
# Deny a prose write until english.md is in context. The instruction to read it is a precondition
# on a category the model has to classify for itself while it is busy
# composing, which it misses often enough to need enforcing here. The denial carries the file's full
# text and so puts it in context itself: the retry succeeds without a separate read, and the gate
# fires at most once per transcript.

PROSE_PATH_PATTERN='(\.md$|(^|/)\.agent/outbox/)'
AGENT_EXEMPT_PATTERN='(^|/)\.agent/(doc|scripts)/'
ENGLISH_READ_PATTERN='"file_path":"[^"]*english\.md"'
ENGLISH_PATH="$(dirname -- "${BASH_SOURCE[0]}")/../languages/english.md"

REASON_UNREAD='Read languages/english.md (beside CLAUDE.md in the Claude home directory) before writing prose that outlives the session, then retry this write.'
REASON_INLINE='This write is prose that outlives the session, and languages/english.md (beside CLAUDE.md in the Claude home directory) is not in context yet. Its full text follows, so no separate read is needed: apply it, then retry this write.'

prose_gate_decision() {
    local file_path="$1" english_in_context="$2"

    GATE_DECISION=allow
    if [[ $english_in_context -eq 1 ]]; then
        return
    fi

    local normalized="${file_path//\\//}"
    if printf '%s' "$normalized" | grep -Eqi "$AGENT_EXEMPT_PATTERN"; then
        return
    fi
    if printf '%s' "$normalized" | grep -Eqi "$PROSE_PATH_PATTERN"; then
        GATE_DECISION=deny
    fi
}

# The first body line of english.md, cut before any character JSON escapes, so it appears verbatim
# in the transcript wherever the file's text does: a Read result, a cat or Get-Content result, or
# this hook's own denial.
english_sentinel() {
    local english_text="$1" line

    while IFS= read -r line; do
        line="${line%$'\r'}"
        if [[ -z $line || $line == \#* ]]; then
            continue
        fi
        printf '%s' "${line%%[\"\\]*}"
        return
    done <<<"$english_text"
}

# An unreadable transcript counts as in context: failing open costs a missed reminder, where
# failing closed would deny every prose write for the rest of the session.
english_md_in_context() {
    local transcript="$1" sentinel="$2"

    [[ -f $transcript ]] || return 0
    if [[ -n $sentinel ]] && grep -Fq -- "$sentinel" "$transcript"; then
        return 0
    fi
    grep -Eq "$ENGLISH_READ_PATTERN" "$transcript"
}

build_denial_reason() {
    local english_text="$1"

    if [[ -z $english_text ]]; then
        printf '%s' "$REASON_UNREAD"
        return
    fi
    printf '%s\n\n%s' "$REASON_INLINE" "$english_text"
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' not found" >&2; exit 1; }

    local request file_path transcript english_text english_in_context=0
    request="$(cat)"
    file_path="$(printf '%s' "$request" | jq -r '.tool_input.file_path // ""')"
    transcript="$(printf '%s' "$request" | jq -r '.transcript_path // ""')"
    english_text="$(cat -- "$ENGLISH_PATH" 2>/dev/null)" || english_text=''
    if english_md_in_context "$transcript" "$(english_sentinel "$english_text")"; then
        english_in_context=1
    fi

    prose_gate_decision "$file_path" "$english_in_context"
    if [[ $GATE_DECISION == deny ]]; then
        jq -cn --arg reason "$(build_denial_reason "$english_text")" \
            '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
    fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main
fi
