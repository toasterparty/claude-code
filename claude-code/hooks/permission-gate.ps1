# PreToolUse gate (Windows): auto-approve every tool call except the policy denials below.
# Bash allow rules are matched against literal command text, so a generated command using shell
# variables or substitution falls through them and prompts; deciding here bypasses that matcher.
# permissions.deny in settings.json is kept as the fallback for when this hook fails to run. It omits
# the verbs that also have read forms (branch, stash, reflog, worktree, submodule, bisect), because a
# deny rule outranks this hook's allow and would block `git branch --show-current`.
# The gate stops mistakes, not evasion: a command assembled at run time, such as `x=git; $x push`
# or `subprocess.run(['git', 'push'])`, passes unseen.
#
# Every change here is mirrored in permission-gate.sh, and test/gate-cases.tsv must pass on both.
param(
    # Load the policy without reading stdin, which is how the tests drive it.
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'

# A gated word counts wherever it is not part of a longer word, so quoting (bash -c '...'),
# substitution (backticks) and paths (/usr/bin/gh) cannot smuggle one past the patterns.
$WordStart = '(^|[^\w-])'
$WordEnd = '([^\w-]|$)'
# Program names fold case, as on the Windows filesystem that resolves them, but git and gh read their
# subcommands and flags with case, so the checks on those match with case too.
$GitCommand = $WordStart + '(?i:git(\.exe)?)'

# Anything that can move the index, HEAD, a ref, the working tree or the repository config. Only
# options may stand between git and its subcommand, so `git ls-files config` is no config call.
# A value option's separate value word is not an option itself, and arguments stop at a separator.
$Blank = '[ \t]'
$GitArg = '[^;&|)\s]'
$GitValueOptions = '-C|-c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix|--attr-source'
$GitOptionValue = '("[^"]*"|''[^'']*''|' + $GitArg + '+)'
$GitOption = '((' + $GitValueOptions + ')' + $Blank + '+' + $GitOptionValue + '|-' + $GitArg + '*)'
$GitArgs = '(' + $Blank + '+' + $GitOption + ')*'
$GitWriteVerbs = 'add|stage|rm|mv|restore|commit|push|pull|merge|rebase|cherry-pick|revert|am|apply' +
    '|stash|reset|checkout|clean|switch|branch|tag|remote|config' +
    '|submodule|worktree|notes|replace|reflog|gc|prune|filter-branch' +
    '|fast-import|sparse-checkout|bisect|update-index|update-ref|symbolic-ref'
$GitWritePattern = $GitCommand + $GitArgs + $Blank + '+(' + $GitWriteVerbs + ')' + $WordEnd

# A patch applied to the working tree is reviewable like any other edit. These flags move the
# index, as --3way does unless told to stay in the cache.
$GitApplyIndexFlags = '--index|--cached|--3way|-3'
$GitApplyIndexPattern = $GitCommand + $GitArgs + $Blank + '+apply(' + $Blank + '+' + $GitArg + '+)*' +
    $Blank + '+(' + $GitApplyIndexFlags + ')' + $WordEnd

# Read forms of write verbs, cut before the write check. Quotes stay out of the arguments, so a commit
# message quoting one of these shapes cannot clear the commit that carries it.
$GitSafeArg = '[^;&|)''"`\s]'
$GitQuotedPath = $Blank + '+-C' + $Blank + '+("[^"]*"|''[^'']*'')'
$GitSafeArgs = '(' + $Blank + '+' + $GitSafeArg + '+|' + $GitQuotedPath + ')*'
# Flags that only shape a listing act on whatever follows them, as git branch -r -d origin/x deletes, so
# they count as a read only when nothing follows them but a listing flag, which refuses every write.
# The short ones cluster (-avv), and none of the write flags share a letter with them.
$GitShapeFlag = '--(sort|format)(=|' + $Blank + '+)' + $GitSafeArg + '*'
$GitBranchShapeFlags = '(' + $Blank + '+(-[avr]+|--all|--remotes|--verbose|' + $GitShapeFlag + '))'
$GitBranchListFlags = '-[avr]*l[avrl]*|--list|--contains|--merged|--no-merged|--points-at|--show-current'
$GitTagShapeFlags = '(' + $Blank + '+' + $GitShapeFlag + ')'
$GitTagListFlags = '-l|-n[0-9]*|--list|--contains|--points-at'
$GitRemoteShapeFlags = '(' + $Blank + '+(-v|--verbose))'
$GitReadShapes = 'worktree' + $Blank + '+list' +
    '|branch' + $GitBranchShapeFlags + '*' + $Blank + '+(' + $GitBranchListFlags + ')' +
    '|tag' + $GitTagShapeFlags + '*' + $Blank + '+(' + $GitTagListFlags + ')' +
    '|remote' + $GitRemoteShapeFlags + '*' + $Blank + '+(show|get-url)' +
    '|config' + $Blank + '+(--get[a-zA-Z-]*|--list|-l)' +
    '|submodule' + $Blank + '+(status|summary)|notes' + $Blank + '+(list|show)' +
    '|reflog' + $Blank + '+show|stash' + $Blank + '+(list|show)' +
    '|apply' +
    '|bisect' + $Blank + '+(log|view|visualize)'
# A subcommand given nothing to act on only lists, except stash, whose bare form stashes.
$GitListVerbs = 'branch' + $GitBranchShapeFlags + '*|tag' + $GitTagShapeFlags + '*|remote' + $GitRemoteShapeFlags + '*' +
    '|worktree|submodule|notes|reflog'
# A config key with no value after it is read back, where a value after it would set it.
$GitConfigKey = 'config' + $Blank + '+[A-Za-z][A-Za-z0-9-]*\.[A-Za-z0-9.-]+'
# Redirections may follow these, since they only move the output.
$GitReadEnd = '(' + $Blank + '+[0-9]*[<>]+&?' + $Blank + '*' + $GitSafeArg + '*)*' + $Blank + '*($|[;&|)\r\n])'
$GitReadPattern = $GitCommand + $GitSafeArgs + $Blank + '+((' + $GitReadShapes + ')' + $WordEnd +
    '|((' + $GitListVerbs + ')|' + $GitConfigKey + ')' + $GitReadEnd + ')'

# A clone under .agent/git/ is the agent's own scratch repository, so its local writes are cut before
# the write check when -C names it, and only a push, which reaches the user's remote, stays denied.
# No other option may join -C, since a second -C or a --git-dir would point back at the user's repo.
# A component past git/ may not open with a dot, so a trailing .. cannot climb out.
$GitScratchComponent = '[\w-][\w.-]*'
$GitScratchTail = '(?i:\.agent[/\\]git[/\\])' + $GitScratchComponent + '([/\\]' + $GitScratchComponent + ')*[/\\]?'
$GitScratchDoubleQuoted = '"([^"]*[/\\])?' + $GitScratchTail + '"'
$GitScratchSingleQuoted = '''([^'']*[/\\])?' + $GitScratchTail + ''''
$GitScratchBare = '([^;&|)\s"'']*[/\\])?' + $GitScratchTail
$GitScratchPath = '(' + $GitScratchDoubleQuoted + '|' + $GitScratchSingleQuoted + '|' + $GitScratchBare + ')'
$GitScratchPattern = $GitCommand + $Blank + '+-C' + $Blank + '+' + $GitScratchPath + $Blank + '+'
$GitScratchMarker = 'scratch_git'
$GitScratchPushPattern = $GitScratchMarker + ' (push|send-pack)' + $WordEnd
$GitScratchOptionPattern = $GitScratchMarker + ' -'

$SudoPattern = $WordStart + 'sudo' + $WordEnd

# A foreground poll loop holds the session until its condition turns true, which took 40 minutes once,
# where run_in_background or Monitor would wake the session when it does. Monitor runs such loops by
# design, so only the shell tools are checked, and only in the foreground.
$PollLoopPattern = $WordStart + '(while|until|for|foreach|do)' + $WordEnd
$PollSleepPattern = $WordStart + '(sleep|start-sleep)' + $WordEnd
$ForegroundShellTools = @('Bash', 'PowerShell')

# A script handed to an interpreter inline that writes files skips the hooks that guard Edit and
# Write, and Claude Code may stop to ask a person to approve it. Checked before heredoc bodies are cut.
$InlineInterpreterPattern = $WordStart + '(python[0-9.]*|py|node|deno|bun|perl|ruby)(' + $Blank + '+-\S*)*(' +
    $Blank + '*<<|' + $Blank + '+(-[A-Za-z]*[ceE]|--eval|-)(' + $Blank + '|$))'
$InlineFileWritePattern = 'writeFile|appendFile|createWriteStream|write_text|write_bytes|File\.write|open\([^)]*["''][wax]b?\+?["'']'
# perl and ruby rewrite their file arguments under -i, as in perl -pi -e or perl -i.bak. Matched
# with case, since -I adds an include path.
$InPlaceEditPattern = $WordStart + '([Pp][Ee][Rr][Ll]|[Rr][Uu][Bb][Yy])(' + $Blank + '+-\S*)*' + $Blank + '+-[A-Za-z]*i(' + $Blank + '|\.|$)'

# Claude Code's own safety checks outrank this hook's allow and prompt, or refuse where nobody can
# answer, so the shapes that trip them are denied here with a remedy. Both deny wider than the checks:
# a needless denial costs one retry, a missed one stalls the session.
# An rm target expands to the root when a variable in it is empty, unless ${VAR:?} aborts first.
# PowerShell reads ${VAR:?} as a drive-qualified variable that expands to empty, so it guards nothing.
$GuardedExpansionPattern = '\$\{[A-Za-z_][A-Za-z0-9_]*:\?[^}]*\}'
$UnguardedRmPattern = $WordStart + 'rm' + $Blank + '[^;&|)\r\n]*[$`]'
# sed can write through -i or a w command, so a sed reaching a Claude home counts as an edit of it.
$SedPattern = $WordStart + 'sed' + $WordEnd
$ClaudeHomePattern = '\.claude'

# No settings.json rule backs this check: any Read deny rule turns a command whose paths cannot be
# resolved up front, like a leading cd or a recursive grep, into a prompt nobody answers unattended.
# .ssh must open a path component, which spares a deploy.ssh file.
$SshDirPattern = '(^|[^\w.-])\.ssh([^\w-]|$)'
# The host list and client config hold no key material. The boundary after the file name excludes
# path and glob characters, so `known_hosts/../id_rsa` and `config*` are not cut.
$SshPlainFilePattern = '\.ssh[/\\](config|known_hosts)(\.old)?([^\w./\\*?-]|$)'

# A process backgrounded inside the shell outlives the tool call with nothing to report its exit and
# no task for TaskStop to reach. run_in_background covers every such case.
$BackgroundLaunchers = 'nohup|disown|setsid|start-job|start-threadjob'
$BackgroundLauncherPattern = $WordStart + '(' + $BackgroundLaunchers + ')' + $WordEnd
# Start-Process detaches unless told to wait, under its alias saps and under start, which is its alias
# in PowerShell and hands off to cmd's start in Git Bash. start counts only where a statement opens
# outside quotes, since npm start and grep 'a\|start' launch nothing. Invoke-Item stays open for
# opening a file in its app.
$StartProcessPattern = $WordStart + '(start-process|saps)' + $WordEnd
# A quote left standing opens the command handed to a shell with -c. A blank must follow, since
# start=$(date +%s) assigns a variable.
$StartCommandPattern = '(^|[;&|({"''])' + $Blank + '*start(' + $Blank + '|$)'
$StartProcessWaitPattern = $WordStart + '([-/]wait|waitforexit|wait-process)' + $WordEnd
# && chains statements, so it becomes a separator that a wait can follow.
$AmpersandAnd = '&&'
$AmpersandNotBackground = '&>>|&>|>&|<&|\|&'
# PowerShell's call operator opens a statement and runs in the foreground.
$AmpersandCallOperator = '(^|[;(|{&])' + $Blank + '*&'
# Only a standalone ampersand backgrounds, unlike one in a URL query string or a quoted name.
$BackgroundAmpersandPattern = $Blank + '&'
# A wait after the last backgrounded job keeps every job from outliving the call.
$WaitStatementPattern = '(^|[;&|(])' + $Blank + '*wait(' + $Blank + '|;|$)'
# A quoted string is data to the shell, unless it is handed to a shell with -c or -Command.
$QuotedString = '"[^"]*"|''[^'']*'''
$ShellCommandWords = 'sh|bash|zsh|dash|ksh|pwsh|powershell|su'
$ShellCommandArgument = '((^|[^\w-])(' + $ShellCommandWords + ')(' + $Blank + '+-\S+)*' + $Blank +
    '+(-[A-Za-z]*c|-[Cc]ommand)' + $Blank + '+(' + $QuotedString + '))'
$QuoteStripPattern = $ShellCommandArgument + '|' + $QuotedString

# Quoted text is data to the git checks, so a search pattern or message that names a write verb is no
# call. These stay in view: an argument of a shell, ssh, eval or interpreter, a value handed to a git
# option, a double-quoted string that expands, and every line piped into a shell.
$GitExecWords = $ShellCommandWords + '|ssh|eval|python[0-9.]*|node|perl|ruby'
$GitQuotedLine = '"[^"\r\n]*"|''[^''\r\n]*'''
$GitExecArgument = '(^|[^\w-])(' + $GitExecWords + ')(' + $Blank + '+' + $GitSafeArg + '+)*' + $Blank +
    '+(' + $GitQuotedLine + ')'
$GitOptionQuoted = $GitCommand + $GitArgs + $Blank + '+(' + $GitValueOptions + ')' + $Blank +
    '+(' + $GitQuotedLine + ')'
$GitExpandingString = '"[^"\r\n]*[$`][^"\r\n]*"'
$GitDataString = '"[^"$`\r\n]*"|''[^''\r\n]*'''
$GitQuoteStripPattern = '(' + $GitExecArgument + '|' + $GitOptionQuoted + '|' + $GitExpandingString + ')|' + $GitDataString
$PipedShellPattern = '\|&?' + $Blank + '*(' + $ShellCommandWords + ')' + $WordEnd

# A heredoc body fed to a reader or an interpreter is cut before every check, so a doc quoting
# `git push` is not read as the command. A body whose opener line names a shell stays in view, and so
# does each body line holding a command substitution under an unquoted delimiter, which runs it.
$HeredocOpener = '<<-?([''"]?)([A-Za-z_][A-Za-z0-9_]*)'
$CommandSubstitutionPattern = '[$][(]|`'
$HeredocDataConsumers = '(^|[^\w-])(cat|tee|python[0-9.]*|node|perl|ruby)([^\w-]|$)'
$HeredocShellWords = '(^|[^\w.-])(' + $ShellCommandWords + '|ssh|eval|source)([^\w.-]|$)'

# gh is inverted: only these read-only shapes pass, everything else is a denial.
$GhInvocationPattern = $WordStart + '(?i:gh(?:\.exe)?)[^\S\r\n]+([^;&|)\r\n]*)'
# A command substitution opens a command of its own, so a gh inside one is split off as its own invocation.
$GhSubstitutionOpener = '\$\(|[<>]\(|`'
$GhBareReads = 'status|version|help|search|api|--version|--help|-h'
$GhReadVerbs = 'view|list|ls|diff|checks|status|watch|download|clone|verify'
# A gh followed by nothing but redirections is a name being looked up, as in `command -v gh >/dev/null`.
$GhRedirectOnly = '^([0-9]*[<>]\S*\s*)+$'
$GhReadOnlyPattern = '^(' + $GhBareReads + ')' + $WordEnd + '|^\S+\s+(' + $GhReadVerbs + ')' + $WordEnd + '|' + $GhRedirectOnly
# Driving CI destroys nothing durable, since a cancelled or rerun job can be dispatched again.
# Matched before the field check, because workflow inputs travel as field flags.
$GhPermittedWriteVerbs = 'rerun|cancel'
$GhPermittedWritePattern = '^workflow\s+run' + $WordEnd + '|^run\s+(' + $GhPermittedWriteVerbs + ')' + $WordEnd
# A graphql query and a mutation share one request shape, and -F query=@file hides the text.
$GhGraphqlPattern = 'graphql'
# gh api sends POST once a field flag appears, unless a read method is named. A short flag may carry its
# value glued on (-ftitle=x, -XDELETE) or follow other short flags in one word (-iX DELETE).
$GhMethodPattern = '(-[A-Za-z]*X|--method)[\s=]*([A-Za-z]+)'
$GhFieldPattern = '(^|\s)(-[A-Za-z]*[fF]|(--field|--raw-field|--input)(\s|=|$))'
$GhReadMethods = @('GET', 'HEAD')

$ReasonAllow = 'Auto-approved by permission-gate.'
$ReasonGit = 'Commands that alter git state (index, HEAD, refs, stash, config) are reserved for the user. Move or delete tracked files with plain mv and rm. For a checkout of your own, clone into .agent/git/<name> and run git -C .agent/git/<name> <command>.'
$ReasonGitPush = 'The remote is reserved for the user, even from a scratch clone under .agent/git/.'
$ReasonGitApply = 'git apply may not stage what it applies; drop --index, --cached and --3way.'
$ReasonSudo = 'Elevation is not permitted. Give the user the command to run themselves, as ! <command> in the prompt, or hand them a script that needs it, untested.'
$ReasonSsh = 'SSH keys are reserved for the user. Connect with ssh, scp or git, which load the keys themselves; of ~/.ssh, only config and known_hosts may be read.'
$ReasonGh = 'Only read-only gh queries and CI dispatch (gh workflow run, gh run rerun, gh run cancel) are permitted. Write anything to post, such as a PR body, comment or review, to .agent/outbox/ for the user.'
$ReasonBackground = 'Background work belongs in the run_in_background parameter, not in the shell.'
$ReasonPollLoop = 'A foreground loop that sleeps holds the session until it ends. Wait for one condition with the same loop under run_in_background, which reports when it exits, or watch for repeated events with Monitor.'
$ReasonInlineWrite = 'An inline interpreter script that writes files skips the hooks on Edit and Write, and may stop for a person to approve it. Edit the file with the Edit or Write tool. Generated output that needs a script goes in a script file, such as under .agent/scripts/, run by its path.'
$ReasonRm = 'Claude Code asks a person to approve an rm whose target could expand to the root, and no hook can clear that prompt. Write every variable in the target as ${VAR:?}, as in rm -rf ${dir:?}/${name:?}, assigning any $(...) to a variable first.'
$ReasonRmPowerShell = 'Claude Code may ask a person to approve an rm whose target could expand to the root, and no hook can clear that prompt. Call Remove-Item by name and throw first if any variable in its path is empty. ${VAR:?} is Bash syntax, which PowerShell expands to empty.'
$ReasonSed = 'Claude Code asks a person to approve sed on a file under a Claude home (~/.claude*), and no hook can clear that prompt. Read the file with grep, cat or the Read tool instead.'

# The last -X/--method flag wins, as in gh itself. Returns '' when none is given.
function Find-GhMethod($ghArgs) {
    $found = [regex]::Matches($ghArgs, $GhMethodPattern)
    if ($found.Count -eq 0) { return '' }
    return $found[$found.Count - 1].Groups[2].Value
}

function Test-GhPermitted($ghArgs) {
    if ($ghArgs -cmatch $GhGraphqlPattern) { return $false }
    if ($ghArgs -cmatch $GhPermittedWritePattern) { return $true }

    $method = Find-GhMethod $ghArgs
    if ($method -and $method -notin $GhReadMethods) { return $false }
    if (-not $method -and $ghArgs -cmatch $GhFieldPattern) { return $false }

    return $ghArgs -cmatch $GhReadOnlyPattern
}

# Cuts the body of every heredoc that is data or a script, keeping the opener line. A heredoc with no
# closing line is kept whole, so a stray << can never hide the rest of the command.
function Remove-DataHeredocs($command) {
    $kept = [System.Collections.Generic.List[string]]::new()
    $delimiter = ''
    $keepBody = $false
    $isQuoted = $false
    $body = [System.Collections.Generic.List[string]]::new()
    $expanding = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $command -split '\r?\n') {
        if ($delimiter) {
            $body.Add($line)
            if (-not $isQuoted -and $line -cmatch $CommandSubstitutionPattern) { $expanding.Add($line) }
            if ($line -cmatch ('^[ \t]*' + $delimiter + '[ \t]*$')) {
                if ($keepBody) { $kept.AddRange($body) } else { $kept.AddRange($expanding) }
                $delimiter = ''
            }
            continue
        }

        $kept.Add($line)
        $opener = [regex]::Match($line, $HeredocOpener)
        if ($opener.Success) {
            $isQuoted = [bool]$opener.Groups[1].Value
            $delimiter = $opener.Groups[2].Value
            $keepBody = $line -cnotmatch $HeredocDataConsumers -or $line -cmatch $HeredocShellWords
            $body.Clear()
            $expanding.Clear()
        }
    }

    if ($delimiter) { $kept.AddRange($body) }
    return $kept -join "`n"
}

function Test-Backgrounds($command) {
    if ($command -match $BackgroundLauncherPattern) { return $true }
    if ($command -match $StartProcessPattern -and $command -notmatch $StartProcessWaitPattern) { return $true }

    $statementText = [regex]::Replace(($command -replace '\r?\n', ';'), $QuoteStripPattern, '${1} ')
    if ($statementText -match $StartCommandPattern -and $command -notmatch $StartProcessWaitPattern) { return $true }

    $ampersandText = (($statementText -replace $AmpersandAnd, ';') -replace $AmpersandNotBackground, ' ') -replace
        $AmpersandCallOperator, '$1 '
    $lastAmpersand = [regex]::Match($ampersandText, $BackgroundAmpersandPattern, 'RightToLeft')
    if (-not $lastAmpersand.Success) { return $false }

    return $ampersandText.Substring($lastAmpersand.Index + $lastAmpersand.Length) -cnotmatch $WaitStatementPattern
}

# The invocation text ends at an ampersand, so `gh 2>&1 pr merge 5` would be read as a bare `gh 2>`.
# Joining the redirection keeps the whole argument list in view.
function Test-GhInvocationsPermitted($command) {
    $split = ($command -replace '>&', '>') -replace $GhSubstitutionOpener, ';'
    $invocations = [regex]::Matches($split, $GhInvocationPattern)
    foreach ($invocation in $invocations) {
        if (-not (Test-GhPermitted $invocation.Groups[2].Value)) { return $false }
    }
    return $true
}

function Test-WritesInline($command) {
    if ($command -cmatch $InPlaceEditPattern) { return $true }
    return $command -match $InlineInterpreterPattern -and $command -match $InlineFileWritePattern
}

function Get-GateDecision($commandText, $toolName, $inBackground = $false) {
    $command = Remove-DataHeredocs $commandText

    if (($command -creplace $SshPlainFilePattern, ' ') -match $SshDirPattern) {
        return @{ decision = 'deny'; reason = $ReasonSsh }
    }

    $gitText = $command -creplace $GitScratchPattern, ('${1}' + $GitScratchMarker + ' ')

    if ($gitText -match '["'']' -and $gitText -cnotmatch $PipedShellPattern) {
        $gitText = [regex]::Replace($gitText, $GitQuoteStripPattern, '${1}')
    }

    if ($gitText -cmatch $GitScratchOptionPattern) {
        return @{ decision = 'deny'; reason = $ReasonGit }
    }

    if ($gitText -cmatch $GitScratchPushPattern) {
        return @{ decision = 'deny'; reason = $ReasonGitPush }
    }

    if ($gitText -cmatch $GitApplyIndexPattern) {
        return @{ decision = 'deny'; reason = $ReasonGitApply }
    }

    if (($gitText -creplace $GitReadPattern, ' ') -cmatch $GitWritePattern) {
        return @{ decision = 'deny'; reason = $ReasonGit }
    }

    # Quoted data, such as a search pattern naming sudo, is no call here either.
    if ($gitText -match $SudoPattern) {
        return @{ decision = 'deny'; reason = $ReasonSudo }
    }

    if (Test-WritesInline $commandText) {
        return @{ decision = 'deny'; reason = $ReasonInlineWrite }
    }

    if (Test-Backgrounds $command) {
        return @{ decision = 'deny'; reason = $ReasonBackground }
    }

    if ($toolName -cin $ForegroundShellTools -and -not $inBackground -and
        $gitText -match $PollLoopPattern -and $gitText -match $PollSleepPattern) {
        return @{ decision = 'deny'; reason = $ReasonPollLoop }
    }

    if (-not (Test-GhInvocationsPermitted $command)) {
        return @{ decision = 'deny'; reason = $ReasonGh }
    }

    if ($toolName -ceq 'PowerShell') {
        if ($command -match $UnguardedRmPattern) {
            return @{ decision = 'deny'; reason = $ReasonRmPowerShell }
        }
    } elseif (($command -replace $GuardedExpansionPattern, ' ') -match $UnguardedRmPattern) {
        return @{ decision = 'deny'; reason = $ReasonRm }
    }

    if ($command -match $ClaudeHomePattern -and $command -match $SedPattern) {
        return @{ decision = 'deny'; reason = $ReasonSed }
    }

    return @{ decision = 'allow'; reason = $ReasonAllow }
}

function Invoke-Gate {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $result = Get-GateDecision ([string]$request.tool_input.command) ([string]$request.tool_name) ($request.tool_input.run_in_background -eq $true)
    $payload = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $result.decision
            permissionDecisionReason = $result.reason
        }
    }
    [Console]::Out.Write((ConvertTo-Json $payload -Depth 5 -Compress))
}

if (-not $LibraryOnly) {
    Invoke-Gate
}
