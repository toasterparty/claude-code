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

# Anything that can move the index, HEAD, a ref, the working tree or the repository config. The
# arguments that may stand between git and its subcommand, such as -C <path>, exclude the command
# separators, so the command after a separator is never read as an argument of the git before it.
GIT_ARG='[^;&|)[:blank:]]'
GIT_ARGS='([[:blank:]]+'"$GIT_ARG"'+)*'
GIT_WRITE_VERBS='add|stage|rm|mv|restore|commit|push|pull|merge|rebase|cherry-pick|revert|am|apply'
GIT_WRITE_VERBS="$GIT_WRITE_VERBS"'|stash|reset|checkout|clean|switch|branch|tag|remote|config'
GIT_WRITE_VERBS="$GIT_WRITE_VERBS"'|submodule|worktree|notes|replace|reflog|gc|prune|filter-branch'
GIT_WRITE_VERBS="$GIT_WRITE_VERBS"'|fast-import|sparse-checkout|bisect|update-index|update-ref|symbolic-ref'
GIT_WRITE_PATTERN="$WORD_START"'git(\.exe)?'"$GIT_ARGS"'[[:blank:]]+('"$GIT_WRITE_VERBS"')'"$WORD_END"

# Shapes cut from the command text before the write check above, so a verb that names both a read and
# a write is denied only in its write form. Worktree creation is among them because it leaves the
# index, HEAD and the working tree untouched. Quotes stay out of the arguments here, so a commit
# message quoting one of these shapes cannot clear the commit that carries it.
GIT_SAFE_ARG="[^;&|)\`'\"[:blank:]]"
GIT_SAFE_ARGS='([[:blank:]]+'"$GIT_SAFE_ARG"'+)*'
GIT_READ_SHAPES='worktree[[:blank:]]+(add|list)'
# The short listing flags cluster (-avv), and none of the write flags share a letter with them.
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|branch[[:blank:]]+(-[avrl]+|--list|--all|--remotes|--verbose|--show-current|--contains|--merged|--no-merged|--points-at|--format|--sort)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|tag[[:blank:]]+(-l|-n[0-9]*|--list|--contains|--points-at|--format|--sort)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|remote[[:blank:]]+(-v|--verbose|show|get-url)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|config[[:blank:]]+(--get[[:alpha:]-]*|--list|-l)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|submodule[[:blank:]]+(status|summary)|notes[[:blank:]]+(list|show)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|reflog[[:blank:]]+show|stash[[:blank:]]+(list|show)'
# These modes of apply print what a patch would do and stop short of touching anything.
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|apply[[:blank:]]+(--check|--stat|--numstat|--summary)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|bisect[[:blank:]]+(log|view|visualize)'
# A subcommand given nothing to act on only lists, except stash, whose bare form stashes.
GIT_LIST_VERBS='branch|tag|remote|worktree|submodule|notes|reflog'
GIT_READ_PATTERN="$WORD_START"'git(\.exe)?'"$GIT_SAFE_ARGS"'[[:blank:]]+(('"$GIT_READ_SHAPES"')'"$WORD_END"'|('"$GIT_LIST_VERBS"')[[:blank:]]*($|[;&|)]))'

SUDO_PATTERN="$WORD_START"'sudo'"$WORD_END"

# Backgrounding from inside the shell hides the process from the harness: the next tool call gets a
# new shell, so the process runs on with nothing to report its exit and no task for TaskOutput or
# TaskStop to reach. The run_in_background parameter covers every case this does, and being denied
# here costs one call where an escaped background process costs the whole run.
BACKGROUND_LAUNCHERS='nohup|disown|setsid|start-job|start-threadjob'
BACKGROUND_LAUNCHER_PATTERN="$WORD_START"'('"$BACKGROUND_LAUNCHERS"')'"$WORD_END"
# Start-Process detaches unless it is told to wait for what it started. Invoke-Item stays open as the
# way to hand a file to its default application.
START_PROCESS_PATTERN="$WORD_START"'start-process'"$WORD_END"
START_PROCESS_WAIT_PATTERN="$WORD_START"'-wait'"$WORD_END"
# The ampersands that redirect or chain, cut before the background operator is looked for.
AMPERSAND_NOT_BACKGROUND='&&|&>>|&>|>&|<&|\|&'
# An ampersand opening a statement is PowerShell's call operator, which runs its command in the
# foreground; a background ampersand never opens one.
AMPERSAND_CALL_OPERATOR='(^|[;(|{&])[[:blank:]]*&'
# What is left backgrounds only where it stands as its own token, which is what tells it apart from
# the ampersands inside a URL query string or a quoted name.
BACKGROUND_AMPERSAND_PATTERN='[[:blank:]]&'

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
REASON_BACKGROUND='Background work belongs in the run_in_background parameter, not in the shell.'

matches() {
    printf '%s' "$1" | grep -Eq -e "$2"
}

# PowerShell reads its own commands without regard to case, so the shapes it shares with the shell
# are matched the same way on both platforms.
matches_ci() {
    printf '%s' "$1" | grep -Eqi -e "$2"
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

backgrounds() {
    local command_text="$1"

    if matches_ci "$command_text" "$BACKGROUND_LAUNCHER_PATTERN"; then
        return 0
    fi

    if matches_ci "$command_text" "$START_PROCESS_PATTERN" && ! matches_ci "$command_text" "$START_PROCESS_WAIT_PATTERN"; then
        return 0
    fi

    local ampersand_text
    ampersand_text="$(printf '%s' "$command_text" | sed -E "s/$AMPERSAND_NOT_BACKGROUND/ /g" | sed -E "s/$AMPERSAND_CALL_OPERATOR/\1 /g")"
    matches "$ampersand_text" "$BACKGROUND_AMPERSAND_PATTERN"
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

    local git_write_text
    git_write_text="$(printf '%s' "$command_text" | sed -E "s/$GIT_READ_PATTERN/ /g")"
    if matches "$git_write_text" "$GIT_WRITE_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GIT
        return
    fi

    if matches "$command_text" "$SUDO_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_SUDO
        return
    fi

    if backgrounds "$command_text"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_BACKGROUND
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
