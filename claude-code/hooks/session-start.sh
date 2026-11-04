#!/usr/bin/env bash
# SessionStart hook (Linux/MacOS): load the project memory in <repo>/.agent/CLAUDE.md, which Claude
# Code itself loads only once a file under .agent/ is read, and warn the user when the deployed
# config lags main. Install stamps the deployed commit beside hooks/.
#
# Every change here is mirrored in session-start.ps1, and test/session-start-cases.tsv must pass on both.

HOOK_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEPLOYED_COMMIT_FILE="$HOOK_DIR/../.deployed-commit"
LATEST_COMMIT_URL='https://api.github.com/repos/toasterparty/claude-code/commits/main'
FETCH_TIMEOUT_S=3
SHORT_SHA_LEN=7

# A resumed session already holds the memory it loaded at its start.
MEMORY_SOURCES='^(startup|clear|compact)$'
DRIFT_SOURCES='^startup$'

# Prints the project memory path for the session's working directory, or nothing.
find_project_memory() {
    local cwd="$1" top
    top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
    [[ -f $top/.agent/CLAUDE.md ]] && printf '%s' "$top/.agent/CLAUDE.md"
    return 0
}

# Prints the drift warning, or nothing when either commit is unknown or they match.
calc_drift_message() {
    local deployed="$1" latest="$2"
    if [[ -z $deployed || -z $latest || $deployed == "$latest" ]]; then
        return
    fi
    printf 'claude-code config deployed from %s, main is at %s' "${deployed:0:SHORT_SHA_LEN}" "${latest:0:SHORT_SHA_LEN}"
}

# Prints the commit main points at, or nothing when offline.
fetch_latest_commit() {
    curl -fsS --max-time "$FETCH_TIMEOUT_S" "$LATEST_COMMIT_URL" 2>/dev/null | jq -r '.sha // empty' 2>/dev/null || true
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' not found" >&2; exit 1; }

    local request source cwd memory_path context='' message='' deployed=''
    request="$(cat)"
    source="$(printf '%s' "$request" | jq -r '.source // ""')"
    cwd="$(printf '%s' "$request" | jq -r '.cwd // ""')"

    if [[ $source =~ $MEMORY_SOURCES && -n $cwd ]]; then
        memory_path="$(find_project_memory "$cwd")"
        if [[ -n $memory_path ]]; then
            context="$(printf 'Contents of %s (project memory):\n\n%s' "$memory_path" "$(cat "$memory_path")")"
        fi
    fi

    if [[ $source =~ $DRIFT_SOURCES && -f $DEPLOYED_COMMIT_FILE ]]; then
        deployed="$(tr -d '[:space:]' < "$DEPLOYED_COMMIT_FILE")"
        message="$(calc_drift_message "$deployed" "$(fetch_latest_commit)")"
    fi

    if [[ -z $context && -z $message ]]; then
        return
    fi
    jq -cn --arg context "$context" --arg message "$message" '
        (if $context != "" then {hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}} else {} end)
        + (if $message != "" then {systemMessage: $message} else {} end)'
}

# Sourcing loads the policy without consuming stdin, which is how the tests drive it.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main
fi
