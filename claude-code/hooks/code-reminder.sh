#!/usr/bin/env bash
# PostToolUse hook (Linux/MacOS): remind a context once, after it edits a code file, to read
# languages/common.md and the language's own file when common.md is not yet in context. A reminder
# rather than a gate like prose-gate, because the first edit of a session is often a one-line fix that
# the rules would not change.
#
# Every change here is mirrored in code-reminder.ps1, and test/code-reminder-cases.tsv must pass on both.

CODE_PATH_PATTERN='(\.(sh|bash|ps1|psm1|py|c|h|cc|cpp|hpp|rs|ts|tsx|js|jsx|mjs|cjs|go|java|kt|cs|rb|lua|swift|zig|mk)|(^|/)(GNU)?[Mm]akefile)$'
# Read, Write and Edit are the tools whose input carries file_path, and each leaves the file in context.
COMMON_READ_PATTERN='"file_path":"[^"]*common\.md"'
COMMON_PATH="$(dirname -- "${BASH_SOURCE[0]}")/../languages/common.md"

REMINDER='This context edited a code file without languages/common.md in context. Before further code edits, read languages/common.md and the language'"'"'s own file among languages/{bash,c,make,python}.md where one exists (beside CLAUDE.md in the Claude home directory), as CLAUDE.md'"'"'s AI Rules require. This reminder appears once per context.'

# Per user, since /tmp is shared and the first user to create the directory would own it.
MARKER_DIR="${TMPDIR:-/tmp}/claude-code-reminder-$UID"
MARKER_NAME_PATTERN='^[A-Za-z0-9_-]+$'

# Sets REMINDER_DECISION to remind or skip.
code_reminder_decision() {
    local file_path="$1" is_reminded="$2" common_in_context="$3"

    REMINDER_DECISION=skip
    if [[ $is_reminded -eq 1 || $common_in_context -eq 1 ]]; then
        return
    fi
    if printf '%s' "${file_path//\\//}" | grep -Eq "$CODE_PATH_PATTERN"; then
        REMINDER_DECISION=remind
    fi
}

# A subagent's context is its own, so it is marked apart from its parent session.
build_marker_name() {
    local session_id="$1" agent_id="$2"
    printf '%s%s' "$session_id" "${agent_id:+-$agent_id}"
}

# A marker name that is not a safe file name cannot be saved, so it counts as reminded: staying
# silent costs one missed reminder, where reminding would repeat on every edit.
is_reminded() {
    local marker_dir="$1" marker_name="$2"
    [[ ! $marker_name =~ $MARKER_NAME_PATTERN || -e $marker_dir/$marker_name ]]
}

save_reminded() {
    local marker_dir="$1" marker_name="$2"
    mkdir -p "$marker_dir"
    : > "$marker_dir/$marker_name"
}

# The first body line of common.md, cut before any character JSON escapes, so it appears verbatim in
# the transcript wherever the file's text does.
common_sentinel() {
    local line
    while IFS= read -r line; do
        line="${line%$'\r'}"
        if [[ -z $line || $line == \#* ]]; then
            continue
        fi
        printf '%s' "${line%%[\"\\]*}"
        return
    done < "$COMMON_PATH"
}

# True when the calling context's transcript holds common.md's text or a file tool call on it. A
# subagent's messages land in a sidechain transcript beside its parent's. An unreadable transcript
# counts as in context, so a broken lookup never repeats the reminder.
common_md_in_context() {
    local transcript="$1" agent_id="$2" sentinel="$3"

    if [[ -n $agent_id ]]; then
        transcript="${transcript%.jsonl}/subagents/agent-$agent_id.jsonl"
    fi
    [[ -f $transcript ]] || return 0
    SENTINEL="$sentinel" PATTERN="$COMMON_READ_PATTERN" awk '
        (ENVIRON["SENTINEL"] != "" && index($0, ENVIRON["SENTINEL"])) || $0 ~ ENVIRON["PATTERN"] { found = 1; exit }
        END { exit !found }
    ' "$transcript"
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' not found" >&2; exit 1; }

    local request file_path transcript agent_id marker_name reminded=0 in_context=0
    request="$(cat)"
    file_path="$(printf '%s' "$request" | jq -r '.tool_input.file_path // ""')"
    transcript="$(printf '%s' "$request" | jq -r '.transcript_path // ""')"
    agent_id="$(printf '%s' "$request" | jq -r '.agent_id // ""')"
    marker_name="$(build_marker_name "$(printf '%s' "$request" | jq -r '.session_id // ""')" "$agent_id")"
    if is_reminded "$MARKER_DIR" "$marker_name"; then
        reminded=1
    elif common_md_in_context "$transcript" "$agent_id" "$(common_sentinel 2>/dev/null)"; then
        in_context=1
    fi

    code_reminder_decision "$file_path" "$reminded" "$in_context"
    if [[ $REMINDER_DECISION != remind ]]; then
        return
    fi
    save_reminded "$MARKER_DIR" "$marker_name"
    jq -cn --arg context "$REMINDER" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
}

# Sourcing loads the policy without consuming stdin, which is how the tests drive it.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main
fi
