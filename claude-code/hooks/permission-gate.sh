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
EXE_SUFFIX='(\.[Ee][Xx][Ee])?'
GIT_COMMAND="$WORD_START"'[Gg][Ii][Tt]'"$EXE_SUFFIX"

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

# Read forms of write verbs, cut before the write check. Quotes stay out of the arguments, so a commit
# message quoting one of these shapes cannot clear the commit that carries it.
GIT_SAFE_ARG="[^;&|)\`'\"[:blank:]]"
GIT_QUOTED_PATH="[[:blank:]]+-C[[:blank:]]+(\"[^\"]*\"|'[^']*')"
GIT_SAFE_ARGS='([[:blank:]]+'"$GIT_SAFE_ARG"'+|'"$GIT_QUOTED_PATH"')*'
# Flags that only shape a listing act on whatever follows them, as git branch -r -d origin/x deletes, so
# they count as a read only when nothing follows them but a listing flag, which refuses every write.
# The short ones cluster (-avv), and none of the write flags share a letter with them.
GIT_SHAPE_FLAG='--(sort|format)(=|[[:blank:]]+)'"$GIT_SAFE_ARG"'*'
GIT_BRANCH_SHAPE_FLAGS='([[:blank:]]+(-[avr]+|--all|--remotes|--verbose|'"$GIT_SHAPE_FLAG"'))'
GIT_BRANCH_LIST_FLAGS='-[avr]*l[avrl]*|--list|--contains|--merged|--no-merged|--points-at|--show-current'
GIT_TAG_SHAPE_FLAGS='([[:blank:]]+'"$GIT_SHAPE_FLAG"')'
GIT_TAG_LIST_FLAGS='-l|-n[0-9]*|--list|--contains|--points-at'
GIT_REMOTE_SHAPE_FLAGS='([[:blank:]]+(-v|--verbose))'
GIT_READ_SHAPES='worktree[[:blank:]]+list'
GIT_READ_SHAPES="$GIT_READ_SHAPES|branch$GIT_BRANCH_SHAPE_FLAGS*[[:blank:]]+($GIT_BRANCH_LIST_FLAGS)"
GIT_READ_SHAPES="$GIT_READ_SHAPES|tag$GIT_TAG_SHAPE_FLAGS*[[:blank:]]+($GIT_TAG_LIST_FLAGS)"
GIT_READ_SHAPES="$GIT_READ_SHAPES|remote$GIT_REMOTE_SHAPE_FLAGS*[[:blank:]]+(show|get-url)"
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|config[[:blank:]]+(--get[[:alpha:]-]*|--list|-l)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|submodule[[:blank:]]+(status|summary)|notes[[:blank:]]+(list|show)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|reflog[[:blank:]]+show|stash[[:blank:]]+(list|show)'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|apply'
GIT_READ_SHAPES="$GIT_READ_SHAPES"'|bisect[[:blank:]]+(log|view|visualize)'
# A subcommand given nothing to act on only lists, except stash, whose bare form stashes.
GIT_LIST_VERBS="branch$GIT_BRANCH_SHAPE_FLAGS*|tag$GIT_TAG_SHAPE_FLAGS*|remote$GIT_REMOTE_SHAPE_FLAGS*"
GIT_LIST_VERBS="$GIT_LIST_VERBS|worktree|submodule|notes|reflog"
# A config key with no value after it is read back, where a value after it would set it.
GIT_CONFIG_KEY='config[[:blank:]]+[[:alpha:]][[:alnum:]-]*\.[[:alnum:].-]+'
# Redirections may follow these, since they only move the output.
GIT_READ_END='([[:blank:]]+[0-9]*[<>]+&?[[:blank:]]*'"$GIT_SAFE_ARG"'*)*[[:blank:]]*($|[;&|)])'
GIT_READ_PATTERN="$GIT_COMMAND$GIT_SAFE_ARGS"'[[:blank:]]+(('"$GIT_READ_SHAPES"')'"$WORD_END"'|(('"$GIT_LIST_VERBS"')|'"$GIT_CONFIG_KEY"')'"$GIT_READ_END)"

# A clone under .agent/git/ is the agent's own scratch repository, so its local writes are cut before
# the write check when -C names it, and only a push, which reaches the user's remote, stays denied.
# No other option may join -C, since a second -C or a --git-dir would point back at the user's repo.
# A component past git/ may not open with a dot, so a trailing .. cannot climb out.
GIT_SCRATCH_COMPONENT='[[:alnum:]_-][[:alnum:]_.-]*'
GIT_SCRATCH_TAIL='\.[Aa][Gg][Ee][Nn][Tt][/\\][Gg][Ii][Tt][/\\]'"$GIT_SCRATCH_COMPONENT"'([/\\]'"$GIT_SCRATCH_COMPONENT"')*[/\\]?'
QUOTE="'"
GIT_SCRATCH_DOUBLE_QUOTED='"([^"]*[/\\])?'"$GIT_SCRATCH_TAIL"'"'
GIT_SCRATCH_SINGLE_QUOTED="$QUOTE([^$QUOTE]*[/\\\\])?$GIT_SCRATCH_TAIL$QUOTE"
GIT_SCRATCH_BARE='([^;&|)[:blank:]"'"$QUOTE"']*[/\\])?'"$GIT_SCRATCH_TAIL"
GIT_SCRATCH_PATH="($GIT_SCRATCH_DOUBLE_QUOTED|$GIT_SCRATCH_SINGLE_QUOTED|$GIT_SCRATCH_BARE)"
GIT_SCRATCH_PATTERN="$GIT_COMMAND"'[[:blank:]]+-C[[:blank:]]+'"$GIT_SCRATCH_PATH"'[[:blank:]]+'
GIT_SCRATCH_MARKER='scratch_git'
GIT_SCRATCH_PUSH_PATTERN="$GIT_SCRATCH_MARKER"' (push|send-pack)'"$WORD_END"
GIT_SCRATCH_OPTION_PATTERN="$GIT_SCRATCH_MARKER"' -'

SUDO_PATTERN="$WORD_START"'sudo'"$WORD_END"

# A foreground poll loop holds the session until its condition turns true, which took 40 minutes once,
# where run_in_background or Monitor would wake the session when it does. Monitor runs such loops by
# design, so only the shell tools are checked, and only in the foreground.
POLL_LOOP_PATTERN="$WORD_START"'(while|until|for|foreach|do)'"$WORD_END"
POLL_SLEEP_PATTERN="$WORD_START"'(sleep|start-sleep)'"$WORD_END"
FOREGROUND_SHELL_TOOLS='^(Bash|PowerShell)$'

# A script handed to an interpreter inline that writes files skips the hooks that guard Edit and
# Write, and Claude Code may stop to ask a person to approve it. Checked before heredoc bodies are cut.
INLINE_INTERPRETER_PATTERN="$WORD_START"'(python[0-9.]*|py|node|deno|bun|perl|ruby)([[:blank:]]+-[^[:blank:]]*)*([[:blank:]]*<<|[[:blank:]]+(-[[:alpha:]]*[ceE]|--eval|-)([[:blank:]]|$))'
INLINE_FILE_WRITE_PATTERN='writeFile|appendFile|createWriteStream|write_text|write_bytes|File\.write|open\([^)]*'"[\"$QUOTE][wax]b?\\+?[\"$QUOTE]"
# perl and ruby rewrite their file arguments under -i, as in perl -pi -e or perl -i.bak. Matched
# with case, since -I adds an include path.
IN_PLACE_EDIT_PATTERN="$WORD_START"'([Pp][Ee][Rr][Ll]|[Rr][Uu][Bb][Yy])([[:blank:]]+-[^[:blank:]]*)*[[:blank:]]+-[[:alpha:]]*i([[:blank:]]|\.|$)'

# Claude Code's own safety checks outrank this hook's allow and prompt, or refuse where nobody can
# answer, so the shapes that trip them are denied here with a remedy. Both deny wider than the checks:
# a needless denial costs one retry, a missed one stalls the session.
# An rm target expands to the root when a variable in it is empty, unless ${VAR:?} aborts first.
# PowerShell reads ${VAR:?} as a drive-qualified variable that expands to empty, so it guards nothing.
GUARDED_EXPANSION_PATTERN='\$\{[A-Za-z_][A-Za-z0-9_]*:\?[^}]*\}'
UNGUARDED_RM_PATTERN="$WORD_START"'rm[[:blank:]][^;&|)]*[$`]'
# sed can write through -i or a w command, so a sed reaching a Claude home counts as an edit of it.
SED_PATTERN="$WORD_START"'sed'"$WORD_END"
CLAUDE_HOME_PATTERN='\.claude'

# No settings.json rule backs this check: any Read deny rule turns a command whose paths cannot be
# resolved up front, like a leading cd or a recursive grep, into a prompt nobody answers unattended.
# .ssh must open a path component, which spares a deploy.ssh file.
SSH_DIR_PATTERN='(^|[^[:alnum:]_.-])\.ssh([^[:alnum:]_-]|$)'
# The host list and client config hold no key material. The boundary after the file name excludes
# path and glob characters, so `known_hosts/../id_rsa` and `config*` are not cut.
SSH_PLAIN_FILE_PATTERN='\.ssh[/\\](config|known_hosts)(\.old)?([^[:alnum:]_./\\*?-]|$)'

# A process backgrounded inside the shell outlives the tool call with nothing to report its exit and
# no task for TaskStop to reach. run_in_background covers every such case.
BACKGROUND_LAUNCHERS='nohup|disown|setsid|start-job|start-threadjob'
BACKGROUND_LAUNCHER_PATTERN="$WORD_START"'('"$BACKGROUND_LAUNCHERS"')'"$WORD_END"
# Start-Process detaches unless told to wait, under its alias saps and under start, which is its alias
# in PowerShell and hands off to cmd's start in Git Bash. start counts only where a statement opens
# outside quotes, since npm start and grep 'a\|start' launch nothing. Invoke-Item stays open for
# opening a file in its app.
START_PROCESS_PATTERN="$WORD_START"'(start-process|saps)'"$WORD_END"
# A quote left standing opens the command handed to a shell with -c. A blank must follow, since
# start=$(date +%s) assigns a variable.
START_COMMAND_PATTERN='(^|[;&|({"'"$QUOTE"'])[[:blank:]]*start([[:blank:]]|$)'
START_PROCESS_WAIT_PATTERN="$WORD_START"'([-/]wait|waitforexit|wait-process)'"$WORD_END"
# && chains statements, so it becomes a separator that a wait can follow.
AMPERSAND_AND='&&'
AMPERSAND_NOT_BACKGROUND='&>>|&>|>&|<&|\|&'
# PowerShell's call operator opens a statement and runs in the foreground.
AMPERSAND_CALL_OPERATOR='(^|[;(|{&])[[:blank:]]*&'
# Only a standalone ampersand backgrounds, unlike one in a URL query string or a quoted name.
BACKGROUND_AMPERSAND_PATTERN='[[:blank:]]&'
# A wait after the last backgrounded job keeps every job from outliving the call.
WAIT_STATEMENT_PATTERN='(^|[;&|(])[[:blank:]]*wait([[:blank:];]|$)'
# A quoted string is data to the shell, unless it is handed to a shell with -c or -Command.
QUOTED_STRING='"[^"]*"|'"$QUOTE[^$QUOTE]*$QUOTE"
SHELL_COMMAND_WORDS='sh|bash|zsh|dash|ksh|pwsh|powershell|su'
SHELL_COMMAND_ARGUMENT='((^|[^[:alnum:]_-])('"$SHELL_COMMAND_WORDS"')([[:blank:]]+-[^[:blank:]]+)*[[:blank:]]+(-[[:alpha:]]*c|-[Cc]ommand)[[:blank:]]+('"$QUOTED_STRING"'))'
QUOTE_STRIP_PATTERN="$SHELL_COMMAND_ARGUMENT|$QUOTED_STRING"

# Quoted text is data to the git checks, so a search pattern or message that names a write verb is no
# call. These stay in view: an argument of a shell, ssh, eval or interpreter, a value handed to a git
# option, a double-quoted string that expands, and every line piped into a shell.
GIT_EXEC_WORDS="$SHELL_COMMAND_WORDS"'|ssh|eval|python[0-9.]*|node|perl|ruby'
GIT_EXEC_ARGUMENT='(^|[^[:alnum:]_-])('"$GIT_EXEC_WORDS"')([[:blank:]]+'"$GIT_SAFE_ARG"'+)*[[:blank:]]+('"$QUOTED_STRING"')'
GIT_OPTION_QUOTED="$GIT_COMMAND$GIT_ARGS"'[[:blank:]]+('"$GIT_VALUE_OPTIONS"')[[:blank:]]+('"$QUOTED_STRING"')'
GIT_EXPANDING_STRING='"[^"]*[$`][^"]*"'
GIT_DATA_STRING='"[^"$`]*"|'"$QUOTE"'[^'"$QUOTE"']*'"$QUOTE"
GIT_QUOTE_STRIP_PATTERN='('"$GIT_EXEC_ARGUMENT|$GIT_OPTION_QUOTED|$GIT_EXPANDING_STRING"')|'"$GIT_DATA_STRING"
PIPED_SHELL_PATTERN='\|&?[[:blank:]]*('"$SHELL_COMMAND_WORDS"')'"$WORD_END"

# A heredoc body fed to a reader or an interpreter is cut before every check, so a doc quoting
# `git push` is not read as the command. A body whose opener line names a shell stays in view, and so
# does each body line holding a command substitution under an unquoted delimiter, which runs it.
HEREDOC_OPENER="<<-?['\"]?[A-Za-z_][A-Za-z0-9_]*"
HEREDOC_OPENER_PREFIX="^<<-?['\"]?"
COMMAND_SUBSTITUTION_PATTERN='[$][(]|`'
HEREDOC_DATA_CONSUMERS='(^|[^[:alnum:]_-])(cat|tee|python[0-9.]*|node|perl|ruby)([^[:alnum:]_-]|$)'
HEREDOC_SHELL_WORDS='(^|[^[:alnum:]_.-])('"$SHELL_COMMAND_WORDS"'|ssh|eval|source)([^[:alnum:]_.-]|$)'

# gh is inverted: only these read-only shapes pass, everything else is a denial.
GH_PROGRAM='[Gg][Hh]'"$EXE_SUFFIX"'[[:space:]]+'
GH_INVOCATION_PATTERN="$WORD_START$GH_PROGRAM"'[^;&|)]*'
GH_INVOCATION_STRIP='^[^[:alnum:]_-]?'"$GH_PROGRAM"
# A command substitution opens a command of its own, so a gh inside one is split off as its own invocation.
GH_SUBSTITUTION_OPENER='\$\(|[<>]\(|`'
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
# gh api sends POST once a field flag appears, unless a read method is named. A short flag may carry its
# value glued on (-ftitle=x, -XDELETE) or follow other short flags in one word (-iX DELETE).
GH_METHOD_PATTERN='(-[[:alpha:]]*X|--method)[[:space:]=]*([[:alpha:]]+)'
GH_FIELD_PATTERN='(^|[[:space:]])(-[[:alpha:]]*[fF]|(--field|--raw-field|--input)([[:space:]]|=|$))'
GH_READ_METHODS='GET|HEAD'

REASON_ALLOW='Auto-approved by permission-gate.'
REASON_GIT='Commands that alter git state (index, HEAD, refs, stash, config) are reserved for the user. Move or delete tracked files with plain mv and rm. For a checkout of your own, clone into .agent/git/<name> and run git -C .agent/git/<name> <command>.'
REASON_GIT_PUSH='The remote is reserved for the user, even from a scratch clone under .agent/git/.'
REASON_GIT_APPLY='git apply may not stage what it applies; drop --index, --cached and --3way.'
REASON_SUDO='Elevation is not permitted. Give the user the command to run themselves, as ! <command> in the prompt, or hand them a script that needs it, untested.'
REASON_SSH='SSH keys are reserved for the user. Connect with ssh, scp or git, which load the keys themselves; of ~/.ssh, only config and known_hosts may be read.'
REASON_GH='Only read-only gh queries and CI dispatch (gh workflow run, gh run rerun, gh run cancel) are permitted. Write anything to post, such as a PR body, comment or review, to .agent/outbox/ for the user.'
REASON_BACKGROUND='Background work belongs in the run_in_background parameter, not in the shell.'
REASON_POLL_LOOP='A foreground loop that sleeps holds the session until it ends. Wait for one condition with the same loop under run_in_background, which reports when it exits, or watch for repeated events with Monitor.'
REASON_INLINE_WRITE='An inline interpreter script that writes files skips the hooks on Edit and Write, and may stop for a person to approve it. Edit the file with the Edit or Write tool. Generated output that needs a script goes in a script file, such as under .agent/scripts/, run by its path.'
REASON_RM='Claude Code asks a person to approve an rm whose target could expand to the root, and no hook can clear that prompt. Write every variable in the target as ${VAR:?}, as in rm -rf ${dir:?}/${name:?}, assigning any $(...) to a variable first.'
REASON_RM_POWERSHELL='Claude Code may ask a person to approve an rm whose target could expand to the root, and no hook can clear that prompt. Call Remove-Item by name and throw first if any variable in its path is empty. ${VAR:?} is Bash syntax, which PowerShell expands to empty.'
REASON_SED='Claude Code asks a person to approve sed on a file under a Claude home (~/.claude*), and no hook can clear that prompt. Read the file with grep, cat or the Read tool instead.'

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
    local rest=$1 method=''
    while [[ $rest =~ $GH_METHOD_PATTERN ]]; do
        method=${BASH_REMATCH[2]}
        rest=${rest#*"${BASH_REMATCH[0]}"}
    done
    printf '%s' "$method"
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
        -v opener="$HEREDOC_OPENER" -v prefix="$HEREDOC_OPENER_PREFIX" -v quote="$QUOTE" \
        -v substitution="$COMMAND_SUBSTITUTION_PATTERN" \
        -v data="$HEREDOC_DATA_CONSUMERS" -v shell="$HEREDOC_SHELL_WORDS" '
        delim != "" {
            body = body $0 "\n"
            if (!quoted && $0 ~ substitution) expanding = expanding $0 "\n"
            if ($0 ~ ("^[ \t]*" delim "[ \t]*$")) {
                printf "%s", (keep ? body : expanding)
                delim = ""
            }
            next
        }
        {
            print
            if (match($0, opener)) {
                delim = substr($0, RSTART, RLENGTH)
                quoted = index(delim, "\"") || index(delim, quote)
                sub(prefix, "", delim)
                keep = ($0 !~ data) || ($0 ~ shell)
                body = ""
                expanding = ""
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

    if [[ $command_text != *'&'* && ${command_text,,} != *start* ]]; then
        return 1
    fi

    local statement_text
    statement_text="$(printf '%s' "$command_text" | tr '\n' ';' | sed -E "s/$QUOTE_STRIP_PATTERN/\1 /g")"
    if matches_ci "$statement_text" "$START_COMMAND_PATTERN" && ! matches_ci "$command_text" "$START_PROCESS_WAIT_PATTERN"; then
        return 0
    fi

    if [[ $statement_text != *'&'* ]]; then
        return 1
    fi

    local ampersand_text
    ampersand_text="$(printf '%s' "$statement_text" | sed -E -e "s/$AMPERSAND_AND/;/g" \
        -e "s/$AMPERSAND_NOT_BACKGROUND/ /g" -e "s/$AMPERSAND_CALL_OPERATOR/\1 /g")"
    if ! matches "$ampersand_text" "$BACKGROUND_AMPERSAND_PATTERN"; then
        return 1
    fi

    ! matches "${ampersand_text##*[[:blank:]]&}" "$WAIT_STATEMENT_PATTERN"
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
    done < <(printf '%s' "$1" | sed -E -e 's/>&/>/g' -e "s/$GH_SUBSTITUTION_OPENER/;/g" | grep -oE "$GH_INVOCATION_PATTERN" || true)
}

unguarded_rm() {
    local rm_text="$1"
    if [[ $rm_text == *'${'* ]]; then
        rm_text="$(printf '%s' "$rm_text" | sed -E "s/$GUARDED_EXPANSION_PATTERN/ /g")"
    fi
    matches_ci "$rm_text" "$UNGUARDED_RM_PATTERN"
}

writes_inline() {
    local command_text="$1"
    if matches "$command_text" "$IN_PLACE_EDIT_PATTERN"; then
        return 0
    fi
    matches_ci "$command_text" "$INLINE_INTERPRETER_PATTERN" && matches_ci "$command_text" "$INLINE_FILE_WRITE_PATTERN"
}

# Sets GATE_DECISION and GATE_REASON for the given command text, the name of the tool running it, and
# whether the call runs in the background.
gate_decision() {
    # Each cut only removes text, so a check whose pattern misses the uncut text skips the fork.
    local command_text=$1 tool_name=${2:-} in_background=${3:-false}
    local raw_text=$command_text
    if [[ $command_text == *'<<'* ]]; then
        command_text="$(strip_data_heredocs "$command_text")"
    fi

    if matches_ci "$command_text" "$SSH_DIR_PATTERN" &&
        matches_ci "$(printf '%s' "$command_text" | sed -E "s#$SSH_PLAIN_FILE_PATTERN# #g")" "$SSH_DIR_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_SSH
        return
    fi

    local git_text=$command_text
    if [[ ${command_text,,} == *.agent* ]]; then
        git_text="$(printf '%s' "$command_text" | sed -E "s#$GIT_SCRATCH_PATTERN#\1$GIT_SCRATCH_MARKER #g")"
    fi

    if [[ $git_text == *[\"\']* ]] && ! matches "$git_text" "$PIPED_SHELL_PATTERN"; then
        git_text="$(printf '%s' "$git_text" | sed -E "s/$GIT_QUOTE_STRIP_PATTERN/\1/g")"
    fi

    if matches "$git_text" "$GIT_SCRATCH_OPTION_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GIT
        return
    fi

    if matches "$git_text" "$GIT_SCRATCH_PUSH_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GIT_PUSH
        return
    fi

    if matches "$git_text" "$GIT_APPLY_INDEX_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GIT_APPLY
        return
    fi

    local git_write_text
    git_write_text="$(printf '%s' "$git_text" | sed -E "s/$GIT_READ_PATTERN/ /g")"
    if matches "$git_write_text" "$GIT_WRITE_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GIT
        return
    fi

    # Quoted data, such as a search pattern naming sudo, is no call here either.
    if matches_ci "$git_text" "$SUDO_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_SUDO
        return
    fi

    if writes_inline "$raw_text"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_INLINE_WRITE
        return
    fi

    if backgrounds "$command_text"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_BACKGROUND
        return
    fi

    if [[ $tool_name =~ $FOREGROUND_SHELL_TOOLS && $in_background != true ]] &&
        matches_ci "$git_text" "$POLL_LOOP_PATTERN" && matches_ci "$git_text" "$POLL_SLEEP_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_POLL_LOOP
        return
    fi

    if ! gh_invocations_permitted "$command_text"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_GH
        return
    fi

    if [[ $tool_name == PowerShell ]]; then
        if matches_ci "$command_text" "$UNGUARDED_RM_PATTERN"; then
            GATE_DECISION=deny
            GATE_REASON=$REASON_RM_POWERSHELL
            return
        fi
    elif unguarded_rm "$command_text"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_RM
        return
    fi

    if matches_ci "$command_text" "$CLAUDE_HOME_PATTERN" && matches_ci "$command_text" "$SED_PATTERN"; then
        GATE_DECISION=deny
        GATE_REASON=$REASON_SED
        return
    fi

    GATE_DECISION=allow
    GATE_REASON=$REASON_ALLOW
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' not found" >&2; exit 1; }

    # Tab-separated, since $(...) would strip a newline before an empty command.
    local request
    request="$(jq -r '(.tool_name // "") + "\t" + (.tool_input.run_in_background == true | tostring) + "\t" + (.tool_input.command // "")')"
    local tool_name=${request%%$'\t'*} in_background
    request=${request#*$'\t'}
    in_background=${request%%$'\t'*}
    gate_decision "${request#*$'\t'}" "$tool_name" "$in_background"
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}' \
        "$GATE_DECISION" "$GATE_REASON"
}

# Sourcing loads the policy without consuming stdin, which is how the tests drive it.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    main
fi
