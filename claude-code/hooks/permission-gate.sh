#!/usr/bin/env bash
# PreToolUse gate (Linux/MacOS): auto-approve every tool call except the policy denials below.
# Bash allow rules are matched against literal command text, so a generated command using shell
# variables or substitution falls through them and prompts; deciding here bypasses that matcher.
# permissions.deny in settings.json is kept as the fallback for when this hook fails to run.
#
# Policy lives in the constants below and is mirrored in permission-gate.ps1; test/run-gate-tests.sh
# and its .ps1 twin assert both against the same cases.

# A gated word counts wherever it is not part of a longer word, on both sides, so quoting
# (bash -c '...'), substitution (backticks) and paths (/usr/bin/gh) cannot smuggle one past the
# patterns. Anchoring on delimiters instead would miss every quoted and substituted form.
WORD_START='(^|[^[:alnum:]_-])'
WORD_END='([^[:alnum:]_-]|$)'

GIT_WRITE_VERBS='add|stage|restore|commit|push|stash|reset|checkout|clean|switch'
GIT_WRITE_PATTERN="$WORD_START"'git([[:space:]]+[^[:space:]]+)*[[:space:]]+('"$GIT_WRITE_VERBS"')'"$WORD_END"
SUDO_PATTERN="$WORD_START"'sudo'"$WORD_END"

# gh is inverted: only these read-only shapes pass, everything else is a denial.
GH_INVOCATION_PATTERN="$WORD_START"'gh[[:space:]]+[^;&|)]*'
GH_INVOCATION_STRIP='^[^[:alnum:]_-]?gh[[:space:]]+'
GH_BARE_READS='status|version|help|search|api'
GH_READ_VERBS='view|list|ls|diff|checks|status|watch|download|clone|verify'
GH_READ_ONLY_PATTERN='^('"$GH_BARE_READS"')'"$WORD_END"'|^[^[:space:]]+[[:space:]]+('"$GH_READ_VERBS"')'"$WORD_END"
# Driving CI destroys nothing durable - a cancelled or rerun job can be dispatched again - so these
# are permitted despite being writes. They carry workflow inputs as field flags, so they are matched
# before the field check.
GH_PERMITTED_WRITE_VERBS='rerun|cancel'
GH_PERMITTED_WRITE_PATTERN='^workflow[[:space:]]+run'"$WORD_END"'|^run[[:space:]]+('"$GH_PERMITTED_WRITE_VERBS"')'"$WORD_END"
# A read query and a mutation are the same request shape, and -F query=@file puts the deciding text
# out of reach of this hook, so the whole graphql endpoint stays denied.
GH_GRAPHQL_PATTERN='graphql'
# gh api sends POST the moment a field flag appears, so a field flag is a write unless the method
# says otherwise. Any explicitly named method other than these is a write on its own.
GH_METHOD_PATTERN='(-X|--method)[[:space:]=]*[A-Za-z]+'
GH_FIELD_PATTERN='(^|[[:space:]])(-f|-F|--field|--raw-field|--input)([[:space:]]|=|$)'
GH_READ_METHODS='GET|HEAD'

REASON_ALLOW='Auto-approved by permission-gate.'
REASON_GIT='Commands that alter git state are reserved for the user.'
REASON_SUDO='Elevation is not permitted.'
REASON_GH='Only read-only gh queries and CI dispatch are permitted.'

matches() {
    printf '%s' "$1" | grep -Eq "$2"
}

# Method named by the last -X/--method flag in the arguments, empty when none is given.
gh_method() {
    printf '%s' "$1" | grep -oE "$GH_METHOD_PATTERN" | tail -1 | grep -oE '[A-Za-z]+$' || true
}

gh_permitted() {
    local gh_args="$1"

    if matches "$gh_args" "$GH_GRAPHQL_PATTERN"; then
        return 1
    fi

    if matches "$gh_args" "$GH_PERMITTED_WRITE_PATTERN"; then
        return 0
    fi

    local method
    method="$(gh_method "$gh_args")"
    local read_method=0
    if [[ ${method^^} =~ ^($GH_READ_METHODS)$ ]]; then
        read_method=1
    fi

    if [[ -n $method && $read_method -eq 0 ]]; then
        return 1
    fi

    if [[ $read_method -eq 0 ]] && matches "$gh_args" "$GH_FIELD_PATTERN"; then
        return 1
    fi

    matches "$gh_args" "$GH_READ_ONLY_PATTERN"
}

gh_invocations_permitted() {
    local invocation gh_args
    while IFS= read -r invocation; do
        gh_args="$(printf '%s' "$invocation" | sed -E "s/$GH_INVOCATION_STRIP//")"
        gh_permitted "$gh_args" || return 1
    done < <(printf '%s' "$1" | grep -oE "$GH_INVOCATION_PATTERN" || true)
}

# Sets GATE_DECISION and GATE_REASON for the given command text.
gate_decision() {
    local command_text="$1"

    if matches "$command_text" "$GIT_WRITE_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GIT
        return
    fi

    if matches "$command_text" "$SUDO_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_SUDO
        return
    fi

    if ! gh_invocations_permitted "$command_text"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GH
        return
    fi

    GATE_DECISION=allow
    GATE_REASON=$REASON_ALLOW
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' not found" >&2; exit 1; }

    local command_text
    command_text="$(jq -r '.tool_input.command // ""')"
    gate_decision "$command_text"
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}' \
        "$GATE_DECISION" "$GATE_REASON"
}

# Sourcing loads the policy without consuming stdin, which is how the tests drive it.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main
fi
