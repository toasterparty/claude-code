#!/usr/bin/env bash
# PreToolUse gate (Linux/MacOS): auto-approve every tool call except the policy denials below.
# Bash allow rules are matched against literal command text, so a generated command using shell
# variables or substitution falls through them and prompts; deciding here bypasses that matcher.
# permissions.deny in settings.json is kept as the fallback for when this hook fails to run.
set -euo pipefail

GIT_WRITE_PATTERN='(^|[[:space:];&|(])git([[:space:]]+[^[:space:]]+)*[[:space:]]+(add|stage|restore|commit|push|stash|reset|checkout|clean|switch)([[:space:]]|$)'
SUDO_PATTERN='(^|[[:space:];&|(])sudo([[:space:]]|$)'

# gh is inverted: only these read-only shapes pass, everything else is a denial.
GH_INVOCATION_PATTERN='(^|[[:space:];&|(])gh[[:space:]]+[^;&|)]*'
GH_READ_ONLY_PATTERN='^(status|version|help)([[:space:]]|$)|^search([[:space:]]|$)|^api([[:space:]]|$)|^[^[:space:]]+[[:space:]]+(view|list|diff|checks|status|watch)([[:space:]]|$)'
# gh api sends POST the moment a field flag appears, with or without an explicit method.
GH_WRITE_PATTERN='(^|[[:space:]])(-f|-F|--field|--raw-field|--input)([[:space:]]|=|$)|(-X|--method)[[:space:]=]+(POST|PUT|PATCH|DELETE)|graphql'

decide() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}' "$1" "$2"
    exit 0
}

request="$(cat)"
command_text="$(printf '%s' "$request" | jq -r '.tool_input.command // ""')"

if printf '%s' "$command_text" | grep -Eq "$GIT_WRITE_PATTERN"; then
    decide deny 'Commands that alter git state are reserved for the user.'
fi

if printf '%s' "$command_text" | grep -Eq "$SUDO_PATTERN"; then
    decide deny 'Elevation is not permitted.'
fi

while IFS= read -r invocation; do
    gh_args="$(printf '%s' "$invocation" | sed -E 's/^[[:space:];&|(]*gh[[:space:]]+//')"
    if printf '%s' "$gh_args" | grep -Eq "$GH_WRITE_PATTERN"; then
        decide deny 'Only read-only gh queries are permitted.'
    fi
    if ! printf '%s' "$gh_args" | grep -Eq "$GH_READ_ONLY_PATTERN"; then
        decide deny 'Only read-only gh queries are permitted.'
    fi
done < <(printf '%s' "$command_text" | grep -oE "$GH_INVOCATION_PATTERN" || true)

decide allow 'Auto-approved by permission-gate.'
