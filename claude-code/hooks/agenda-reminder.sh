#!/usr/bin/env bash
# PostToolUse hook (Linux/MacOS): remind the session once, after its first edit to a project file,
# to update the agenda before it reports the task done. A reminder rather than a gate: the hook
# cannot tell whether the edit changed anything open, and a blocked stop would cost a turn every
# time it had not.
#
# Every change here is mirrored in agenda-reminder.ps1, and test/agenda-reminder-cases.tsv must pass on both.

# The agent's own working files, the agenda among them, are not project work.
AGENT_DIR_PATTERN='(^|/)\.agent/'

REMINDER='This session has now edited project files. Before reporting the task done, update the project agenda as the user CLAUDE.md describes. This reminder appears once per session.'

# Per user, since /tmp is shared and the first user to create the directory would own it.
MARKER_DIR="${TMPDIR:-/tmp}/claude-agenda-reminder-$UID"
SESSION_ID_PATTERN='^[A-Za-z0-9_-]+$'

# Sets REMINDER_DECISION to remind or skip. A subagent is skipped because only the top-level
# session edits the agenda.
agenda_reminder_decision() {
    local file_path="$1" is_subagent="$2" is_reminded="$3"

    REMINDER_DECISION=skip
    if [[ $is_subagent -eq 1 || $is_reminded -eq 1 ]]; then
        return
    fi

    local normalized="${file_path//\\//}"
    if printf '%s' "$normalized" | grep -Eqi "$AGENT_DIR_PATTERN"; then
        return
    fi
    REMINDER_DECISION=remind
}

# True once save_reminded has run for the session. A session without a usable id, one that is not a
# safe file name, cannot be marked, so it counts as reminded: staying silent costs one missed
# reminder, where reminding would repeat on every edit.
is_reminded() {
    local marker_dir="$1" session_id="$2"

    [[ ! $session_id =~ $SESSION_ID_PATTERN || -e $marker_dir/$session_id ]]
}

save_reminded() {
    local marker_dir="$1" session_id="$2"

    mkdir -p "$marker_dir"
    : > "$marker_dir/$session_id"
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' not found" >&2; exit 1; }

    local request file_path session_id is_subagent reminded=0
    request="$(cat)"
    file_path="$(printf '%s' "$request" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')"
    session_id="$(printf '%s' "$request" | jq -r '.session_id // ""')"
    is_subagent="$(printf '%s' "$request" | jq -r 'if (.agent_id // "") != "" then 1 else 0 end')"
    if is_reminded "$MARKER_DIR" "$session_id"; then
        reminded=1
    fi

    agenda_reminder_decision "$file_path" "$is_subagent" "$reminded"
    if [[ $REMINDER_DECISION != remind ]]; then
        return
    fi
    save_reminded "$MARKER_DIR" "$session_id"
    jq -cn --arg context "$REMINDER" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
}

# Sourcing loads the policy without consuming stdin, which is how the tests drive it.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main
fi
