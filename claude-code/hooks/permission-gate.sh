#!/usr/bin/env bash
# PreToolUse gate (Linux/MacOS): auto-approve every tool call except the policy denials below.
# Bash allow rules are matched against literal command text, so a generated command using shell
# variables or substitution falls through them and prompts; deciding here bypasses that matcher.
# permissions.deny in settings.json is kept as the fallback for when this hook fails to run. It omits
# the verbs that also have read forms (branch, stash, reflog, worktree, submodule, bisect), because a
# deny rule outranks this hook's allow and would block `git branch --show-current`.
# The gate stops mistakes, not evasion: a command assembled at run time, such as `x=git; $x push`
# or `subprocess.run(['git', 'push'])`, passes unseen.
#
# Every change here is mirrored in permission-gate.ps1, and test/gate-cases.tsv must pass on both.

# A gated word counts wherever it is not part of a longer word, so quoting (bash -c '...'),
# substitution (backticks) and paths (/usr/bin/gh) cannot smuggle one past the patterns.
WORD_START='(^|[^[:alnum:]_-])'
WORD_END='([^[:alnum:]_-]|$)'
# Program names fold case, as on the macOS filesystem that resolves them. Spelled as bracket
# classes because sed has no portable case-insensitive flag.
GIT_COMMAND="$WORD_START"'[Gg][Ii][Tt](\.[Ee][Xx][Ee])?'

# Anything that can move the index, HEAD, a ref, the working tree or the repository config. Only
# options may stand between git and its subcommand, so `git ls-files config` is no config call.
# A value option's separate value word is not an option itself, and arguments stop at a separator.
GIT_ARG='[^;&|)[:blank:]]'
GIT_VALUE_OPTIONS='-C|-c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix|--attr-source'
GIT_OPTION_VALUE="(\"[^\"]*\"|'[^']*'|$GIT_ARG+)"
GIT_OPTION='(('"$GIT_VALUE_OPTIONS"')[[:blank:]]+'"$GIT_OPTION_VALUE"'|-'"$GIT_ARG"'*)'
GIT_ARGS='([[:blank:]]+'"$GIT_OPTION"')*'
GIT_WRITE_VERBS='add|stage|rm|mv|restore|commit|push|pull|merge|rebase|cherry-pick|revert|am|apply'
GIT_WRITE_VERBS="$GIT_WRITE_VERBS"'|stash|reset|checkout|clean|switch|branch|tag|remote|config'
GIT_WRITE_VERBS="$GIT_WRITE_VERBS"'|submodule|worktree|notes|replace|reflog|gc|prune|filter-branch'
GIT_WRITE_VERBS="$GIT_WRITE_VERBS"'|fast-import|sparse-checkout|bisect|update-index|update-ref|symbolic-ref'
GIT_WRITE_PATTERN="$GIT_COMMAND$GIT_ARGS"'[[:blank:]]+('"$GIT_WRITE_VERBS"')'"$WORD_END"

# A patch applied to the working tree is reviewable like any other edit. These flags move the
# index, as --3way does unless told to stay in the cache.
GIT_APPLY_INDEX_FLAGS='--index|--cached|--3way|-3'
GIT_APPLY_INDEX_PATTERN="$GIT_COMMAND$GIT_ARGS"'[[:blank:]]+apply([[:blank:]]+'"$GIT_ARG"'+)*[[:blank:]]+('"$GIT_APPLY_INDEX_FLAGS"')'"$WORD_END"

# Read forms of write verbs, cut before the write check. Worktree creation leaves the index, HEAD
# and the working tree untouched. Quotes stay out of the arguments, so a commit message quoting one
# of these shapes cannot clear the commit that carries it.
GIT_SAFE_ARG="[^;&|)\`'\"[:blank:]]"
GIT_QUOTED_PATH="[[:blank:]]+-C[[:blank:]]+(\"[^\"]*\"|'[^']*')"
GIT_SAFE_ARGS='([[:blank:]]+'"$GIT_SAFE_ARG"'+|'"$GIT_QUOTED_PATH"')*'
GIT_READ_SHAPES='worktree[[:blank:]]+(add|list)'
# The short listing flags cluster (-avv), and none of the write flags share a letter with them.
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|branch[[:blank:]]+(-[avrl]+|--list|--all|--remotes|--verbose|--show-current|--contains|--merged|--no-merged|--points-at|--format|--sort)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|tag[[:blank:]]+(-l|-n[0-9]*|--list|--contains|--points-at|--format|--sort)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|remote[[:blank:]]+(-v|--verbose|show|get-url)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|config[[:blank:]]+(--get[[:alpha:]-]*|--list|-l)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|submodule[[:blank:]]+(status|summary)|notes[[:blank:]]+(list|show)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|reflog[[:blank:]]+show|stash[[:blank:]]+(list|show)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|apply'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|bisect[[:blank:]]+(log|view|visualize)'
# A subcommand given nothing to act on only lists, except stash, whose bare form stashes.
GIT_LIST_VERBS='branch|tag|remote|worktree|submodule|notes|reflog'
# A config key with no value after it is read back, where a value after it would set it.
GIT_CONFIG_KEY='config[[:blank:]]+[[:alpha:]][[:alnum:]-]*\.[[:alnum:].-]+'
GIT_READ_PATTERN="$GIT_COMMAND$GIT_SAFE_ARGS"'[[:blank:]]+(('"$GIT_READ_SHAPES"')'"$WORD_END"'|(('"$GIT_LIST_VERBS"')|'"$GIT_CONFIG_KEY"')[[:blank:]]*($|[;&|)]))'

SUDO_PATTERN="$WORD_START"'sudo'"$WORD_END"

# No settings.json rule backs this check: any Read deny rule turns a command whose paths cannot be
# resolved up front, like a leading cd or a recursive grep, into a prompt nobody answers unattended.
# .ssh must open a path component, which spares a deploy.ssh file.
SSH_DIR_PATTERN='(^|[^[:alnum:]_.-])\.ssh([^[:alnum:]_-]|$)'
# The host list and client config hold no key material. The boundary after the file name excludes
# path and glob characters, so `known_hosts/../id_rsa` and `config*` are not cut.
SSH_PLAIN_FILE_PATTERN='\.ssh[/\\](config|known_hosts)(\.old)?([^[:alnum:]_./\\*?-]|$)'

# A process backgrounded inside the shell outlives the tool call with nothing to report its exit and
# no task for TaskOutput or TaskStop to reach. run_in_background covers every such case.
BACKGROUND_LAUNCHERS='nohup|disown|setsid|start-job|start-threadjob'
BACKGROUND_LAUNCHER_PATTERN="$WORD_START"'('"$BACKGROUND_LAUNCHERS"')'"$WORD_END"
# Start-Process detaches unless told to wait. Invoke-Item stays open for opening a file in its app.
START_PROCESS_PATTERN="$WORD_START"'start-process'"$WORD_END"
START_PROCESS_WAIT_PATTERN="$WORD_START"'(-wait|waitforexit|wait-process)'"$WORD_END"
AMPERSAND_NOT_BACKGROUND='&&|&>>|&>|>&|<&|\|&'
# PowerShell's call operator opens a statement and runs in the foreground.
AMPERSAND_CALL_OPERATOR='(^|[;(|{&])[[:blank:]]*&'
# Only a standalone ampersand backgrounds, unlike one in a URL query string or a quoted name.
BACKGROUND_AMPERSAND_PATTERN='[[:blank:]]&'
# A backgrounded job the same command waits for cannot outlive the call.
WAIT_STATEMENT_PATTERN='(^|[;&|(])[[:blank:]]*wait([[:blank:];]|$)'
# A quoted string is data to the shell, unless it is handed to a shell with -c or -Command.
QUOTED_STRING='"[^"]*"|'"'"'[^'"'"']*'"'"
SHELL_COMMAND_WORDS='sh|bash|zsh|dash|ksh|pwsh|powershell|su'
SHELL_COMMAND_ARGUMENT='((^|[^[:alnum:]_-])('"$SHELL_COMMAND_WORDS"')([[:blank:]]+-[^[:blank:]]+)*[[:blank:]]+(-[[:alpha:]]*c|-[Cc]ommand)[[:blank:]]+('"$QUOTED_STRING"'))'
QUOTE_STRIP_PATTERN="$SHELL_COMMAND_ARGUMENT|$QUOTED_STRING"

# A heredoc body fed to a reader or an interpreter is cut before every check, so a doc quoting
# `git push` is not read as the command. A body whose opener line names a shell stays in view.
HEREDOC_OPENER="<<-?['\"]?[A-Za-z_][A-Za-z0-9_]*"
HEREDOC_OPENER_PREFIX="^<<-?['\"]?"
HEREDOC_DATA_CONSUMERS='(^|[^[:alnum:]_-])(cat|tee|python[0-9.]*|node|perl|ruby)([^[:alnum:]_-]|$)'
HEREDOC_SHELL_WORDS='(^|[^[:alnum:]_.-])('"$SHELL_COMMAND_WORDS"'|ssh|eval|source)([^[:alnum:]_.-]|$)'

# gh is inverted: only these read-only shapes pass, everything else is a denial.
GH_INVOCATION_PATTERN="$WORD_START"'[Gg][Hh][[:space:]]+[^;&|)]*'
GH_INVOCATION_STRIP='^[^[:alnum:]_-]?[Gg][Hh][[:space:]]+'
GH_BARE_READS='status|version|help|search|api|--version|--help|-h'
GH_READ_VERBS='view|list|ls|diff|checks|status|watch|download|clone|verify'
# A gh followed by nothing but redirections is a name being looked up, as in `command -v gh >/dev/null`.
GH_REDIRECT_ONLY='^([0-9]*[<>][^[:space:]]*[[:space:]]*)+$'
GH_READ_ONLY_PATTERN='^('"$GH_BARE_READS"')'"$WORD_END"'|^[^[:space:]]+[[:space:]]+('"$GH_READ_VERBS"')'"$WORD_END"'|'"$GH_REDIRECT_ONLY"
# Driving CI destroys nothing durable, since a cancelled or rerun job can be dispatched again.
# Matched before the field check, because workflow inputs travel as field flags.
GH_PERMITTED_WRITE_VERBS='rerun|cancel'
GH_PERMITTED_WRITE_PATTERN='^workflow[[:space:]]+run'"$WORD_END"'|^run[[:space:]]+('"$GH_PERMITTED_WRITE_VERBS"')'"$WORD_END"
# A graphql query and a mutation share one request shape, and -F query=@file hides the text.
GH_GRAPHQL_PATTERN='graphql'
# gh api sends POST once a field flag appears, unless a read method is named.
GH_METHOD_PATTERN='(-X|--method)[[:space:]=]*[A-Za-z]+'
GH_FIELD_PATTERN='(^|[[:space:]])(-f|-F|--field|--raw-field|--input)([[:space:]]|=|$)'
GH_READ_METHODS='GET|HEAD'

REASON_ALLOW='Auto-approved by permission-gate.'
REASON_GIT='Commands that alter git state (index, HEAD, refs, stash, config) are reserved for the user. Move or delete tracked files with plain mv and rm.'
REASON_GIT_APPLY='git apply may not stage what it applies; drop --index, --cached and --3way.'
REASON_SUDO='Elevation is not permitted.'
REASON_SSH='SSH keys are reserved for the user.'
REASON_GH='Only read-only gh queries and CI dispatch are permitted.'
REASON_BACKGROUND='Background work belongs in the run_in_background parameter, not in the shell.'

# Line by line like grep, but in-process, since a fork costs a visible delay under Git Bash.
matches() {
    local line
    while IFS= read -r line; do
        if [[ $line =~ $2 ]]; then
            return 0
        fi
    done <<< "$1"
    return 1
}

# PowerShell reads its own commands without regard to case, so the shapes it shares with the shell
# are matched the same way on both platforms.
matches_ci() {
    local status=0
    shopt -s nocasematch
    matches "$1" "$2" || status=1
    shopt -u nocasematch
    return $status
}

# The last -X/--method flag wins, as in gh itself. Prints nothing when none is given.
find_gh_method() {
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
    method="$(find_gh_method "$gh_args")"
    if [[ -n $method && ! ${method^^} =~ ^($GH_READ_METHODS)$ ]]; then
        return 1
    fi

    if [[ -z $method ]] && matches "$gh_args" "$GH_FIELD_PATTERN"; then
        return 1
    fi

    matches "$gh_args" "$GH_READ_ONLY_PATTERN"
}

# Cuts the body of every heredoc that is data or a script, keeping the opener line. A heredoc with no
# closing line is kept whole, so a stray << can never hide the rest of the command.
strip_data_heredocs() {
    printf '%s\n' "$1" | awk \
        -v opener="$HEREDOC_OPENER" -v prefix="$HEREDOC_OPENER_PREFIX" \
        -v data="$HEREDOC_DATA_CONSUMERS" -v shell="$HEREDOC_SHELL_WORDS" '
        delim != "" {
            body = body $0 "\n"
            if ($0 ~ ("^[ \t]*" delim "[ \t]*$")) {
                if (keep) printf "%s", body
                delim = ""
            }
            next
        }
        {
            print
            if (match($0, opener)) {
                delim = substr($0, RSTART, RLENGTH)
                sub(prefix, "", delim)
                keep = ($0 !~ data) || ($0 ~ shell)
                body = ""
            }
        }
        END { if (delim != "") printf "%s", body }
    '
}

backgrounds() {
    local command_text="$1"

    if matches_ci "$command_text" "$BACKGROUND_LAUNCHER_PATTERN"; then
        return 0
    fi

    if matches_ci "$command_text" "$START_PROCESS_PATTERN" && ! matches_ci "$command_text" "$START_PROCESS_WAIT_PATTERN"; then
        return 0
    fi

    if [[ $command_text != *'&'* ]]; then
        return 1
    fi

    local ampersand_text
    ampersand_text="$(printf '%s' "$command_text" | tr '\n' ';' | sed -E "s/$QUOTE_STRIP_PATTERN/\1 \2/g")"
    if matches "$ampersand_text" "$WAIT_STATEMENT_PATTERN"; then
        return 1
    fi

    ampersand_text="$(printf '%s' "$ampersand_text" | sed -E -e "s/$AMPERSAND_NOT_BACKGROUND/ /g" -e "s/$AMPERSAND_CALL_OPERATOR/\1 /g")"
    matches "$ampersand_text" "$BACKGROUND_AMPERSAND_PATTERN"
}

# The invocation text ends at an ampersand, so `gh 2>&1 pr merge 5` would be read as a bare `gh 2>`.
# Joining the redirection keeps the whole argument list in view.
gh_invocations_permitted() {
    if ! matches "$1" "$GH_INVOCATION_PATTERN"; then
        return 0
    fi

    local invocation gh_args
    while IFS= read -r invocation; do
        gh_args="$(printf '%s' "$invocation" | sed -E "s/$GH_INVOCATION_STRIP//")"
        gh_permitted "$gh_args" || return 1
    done < <(printf '%s' "$1" | sed -E 's/>&/>/g' | grep -oE "$GH_INVOCATION_PATTERN" || true)
}

# Sets GATE_DECISION and GATE_REASON for the given command text.
gate_decision() {
    # Each cut only removes text, so a check whose pattern misses the uncut text skips the fork.
    local command_text=$1
    if [[ $command_text == *'<<'* ]]; then
        command_text="$(strip_data_heredocs "$command_text")"
    fi

    if matches_ci "$command_text" "$SSH_DIR_PATTERN" &&
        matches_ci "$(printf '%s' "$command_text" | sed -E "s#$SSH_PLAIN_FILE_PATTERN# #g")" "$SSH_DIR_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_SSH
        return
    fi

    if matches "$command_text" "$GIT_APPLY_INDEX_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GIT_APPLY
        return
    fi

    local git_write_text
    git_write_text="$(printf '%s' "$command_text" | sed -E "s/$GIT_READ_PATTERN/ /g")"
    if matches "$git_write_text" "$GIT_WRITE_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GIT
        return
    fi

    if matches_ci "$command_text" "$SUDO_PATTERN"; then
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
