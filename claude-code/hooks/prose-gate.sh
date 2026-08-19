#!/usr/bin/env bash
# PreToolUse gate (Linux/MacOS): deny a prose write until english.md is in context. The instruction
# to read it is a precondition on a category the model has to classify for itself while it is busy
# composing, which it misses often enough to need enforcing here. A denial is self-healing: the
# model reads the file and retries, so the cost is one blocked call per session.
#
# Scope is markdown plus everything under .agent/outbox/. Source files are out: gating them would
# block the first mechanical edit of every session for the sake of the occasional comment.
#
# Policy lives in the constants below and is mirrored in prose-gate.ps1; test/run-prose-gate-tests.sh
# and its .ps1 twin assert both against the same cases.

PROSE_PATH_PATTERN='(\.md$|(^|/)\.agent/outbox/)'
# Read, Write and Edit are the only tools whose input carries file_path, and each of them leaves the
# file in context, so any of the three counts. Glob and Grep name their target `path` and do not.
ENGLISH_READ_PATTERN='"file_path":"[^"]*english\.md"'

REASON_UNREAD='Read languages/english.md (beside CLAUDE.md in the Claude home directory) before writing prose that outlives the session, then retry this write.'

# Sets GATE_DECISION for a write to $1, where $2 is 1 when english.md is already in context.
prose_gate_decision() {
    local file_path="$1" english_in_context="$2"

    GATE_DECISION=allow
    if [[ $english_in_context -eq 1 ]]; then
        return
    fi

    # The twin runs against Windows paths, so both hooks compare one separator.
    local normalized="${file_path//\\//}"
    if printf '%s' "$normalized" | grep -Eqi "$PROSE_PATH_PATTERN"; then
        GATE_DECISION=deny
    fi
}

# True when the session transcript at $1 shows english.md passing through a file tool. An unreadable
# transcript is true as well: failing open costs a missed reminder, where failing closed would deny
# every prose write for the rest of the session and leave the retry no way to succeed.
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
    # Only the denial is a decision. Staying silent on allow leaves the write to the permission flow
    # it would have gone through anyway, rather than making this hook a second approval authority.
    if [[ $GATE_DECISION == deny ]]; then
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' \
            "$REASON_UNREAD"
    fi
}

# Sourcing loads the policy without consuming stdin, which is how the tests drive it.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main
fi
