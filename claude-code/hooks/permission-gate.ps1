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
$GitCommand = $WordStart + 'git(\.exe)?'

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

# Read forms of write verbs, cut before the write check. Worktree creation leaves the index, HEAD
# and the working tree untouched. Quotes stay out of the arguments, so a commit message quoting one
# of these shapes cannot clear the commit that carries it.
$GitSafeArg = '[^;&|)''"`\s]'
$GitQuotedPath = $Blank + '+-C' + $Blank + '+("[^"]*"|''[^'']*'')'
$GitSafeArgs = '(' + $Blank + '+' + $GitSafeArg + '+|' + $GitQuotedPath + ')*'
$GitReadShapes = 'worktree' + $Blank + '+(add|list)' +
    # The short listing flags cluster (-avv), and none of the write flags share a letter with them.
    '|branch' + $Blank + '+(-[avrl]+|--list|--all|--remotes|--verbose|--show-current|--contains|--merged|--no-merged|--points-at|--format|--sort)' +
    '|tag' + $Blank + '+(-l|-n[0-9]*|--list|--contains|--points-at|--format|--sort)' +
    '|remote' + $Blank + '+(-v|--verbose|show|get-url)' +
    '|config' + $Blank + '+(--get[a-zA-Z-]*|--list|-l)' +
    '|submodule' + $Blank + '+(status|summary)|notes' + $Blank + '+(list|show)' +
    '|reflog' + $Blank + '+show|stash' + $Blank + '+(list|show)' +
    '|apply' +
    '|bisect' + $Blank + '+(log|view|visualize)'
# A subcommand given nothing to act on only lists, except stash, whose bare form stashes.
$GitListVerbs = 'branch|tag|remote|worktree|submodule|notes|reflog'
# A config key with no value after it is read back, where a value after it would set it.
$GitConfigKey = 'config' + $Blank + '+[A-Za-z][A-Za-z0-9-]*\.[A-Za-z0-9.-]+'
$GitReadPattern = $GitCommand + $GitSafeArgs + $Blank + '+((' + $GitReadShapes + ')' + $WordEnd +
    '|((' + $GitListVerbs + ')|' + $GitConfigKey + ')' + $Blank + '*($|[;&|)\r\n]))'

$SudoPattern = $WordStart + 'sudo' + $WordEnd

# No settings.json rule backs this check: any Read deny rule turns a command whose paths cannot be
# resolved up front, like a leading cd or a recursive grep, into a prompt nobody answers unattended.
# .ssh must open a path component, which spares a deploy.ssh file.
$SshDirPattern = '(^|[^\w.-])\.ssh([^\w-]|$)'
# The host list and client config hold no key material. The boundary after the file name excludes
# path and glob characters, so `known_hosts/../id_rsa` and `config*` are not cut.
$SshPlainFilePattern = '\.ssh[/\\](config|known_hosts)(\.old)?([^\w./\\*?-]|$)'

# A process backgrounded inside the shell outlives the tool call with nothing to report its exit and
# no task for TaskOutput or TaskStop to reach. run_in_background covers every such case.
$BackgroundLaunchers = 'nohup|disown|setsid|start-job|start-threadjob'
$BackgroundLauncherPattern = $WordStart + '(' + $BackgroundLaunchers + ')' + $WordEnd
# Start-Process detaches unless told to wait. Invoke-Item stays open for opening a file in its app.
$StartProcessPattern = $WordStart + 'start-process' + $WordEnd
$StartProcessWaitPattern = $WordStart + '(-wait|waitforexit|wait-process)' + $WordEnd
$AmpersandNotBackground = '&&|&>>|&>|>&|<&|\|&'
# PowerShell's call operator opens a statement and runs in the foreground.
$AmpersandCallOperator = '(^|[;(|{&])' + $Blank + '*&'
# Only a standalone ampersand backgrounds, unlike one in a URL query string or a quoted name.
$BackgroundAmpersandPattern = $Blank + '&'
# A backgrounded job the same command waits for cannot outlive the call.
$WaitStatementPattern = '(^|[;&|(])' + $Blank + '*wait(' + $Blank + '|;|$)'
# A quoted string is data to the shell, unless it is handed to a shell with -c or -Command.
$QuotedString = '"[^"]*"|''[^'']*'''
$ShellCommandWords = 'sh|bash|zsh|dash|ksh|pwsh|powershell|su'
$ShellCommandArgument = '((^|[^\w-])(' + $ShellCommandWords + ')(' + $Blank + '+-\S+)*' + $Blank +
    '+(-[A-Za-z]*c|-[Cc]ommand)' + $Blank + '+(' + $QuotedString + '))'
$QuoteStripPattern = $ShellCommandArgument + '|' + $QuotedString

# A heredoc body fed to a reader or an interpreter is cut before every check, so a doc quoting
# `git push` is not read as the command. A body whose opener line names a shell stays in view.
$HeredocOpener = '<<-?[''"]?([A-Za-z_][A-Za-z0-9_]*)'
$HeredocDataConsumers = '(^|[^\w-])(cat|tee|python[0-9.]*|node|perl|ruby)([^\w-]|$)'
$HeredocShellWords = '(^|[^\w.-])(' + $ShellCommandWords + '|ssh|eval|source)([^\w.-]|$)'

# gh is inverted: only these read-only shapes pass, everything else is a denial.
$GhInvocationPattern = $WordStart + 'gh\s+([^;&|)\r\n]*)'
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
# gh api sends POST once a field flag appears, unless a read method is named.
$GhMethodPattern = '(-X|--method)[\s=]*([A-Za-z]+)'
$GhFieldPattern = '(^|\s)(-f|-F|--field|--raw-field|--input)(\s|=|$)'
$GhReadMethods = @('GET', 'HEAD')

$ReasonAllow = 'Auto-approved by permission-gate.'
$ReasonGit = 'Commands that alter git state (index, HEAD, refs, stash, config) are reserved for the user. Move or delete tracked files with plain mv and rm.'
$ReasonGitApply = 'git apply may not stage what it applies; drop --index, --cached and --3way.'
$ReasonSudo = 'Elevation is not permitted.'
$ReasonSsh = 'SSH keys are reserved for the user.'
$ReasonGh = 'Only read-only gh queries and CI dispatch are permitted.'
$ReasonBackground = 'Background work belongs in the run_in_background parameter, not in the shell.'

# The last -X/--method flag wins, as in gh itself. Returns '' when none is given.
function Find-GhMethod($ghArgs) {
    $found = [regex]::Matches($ghArgs, $GhMethodPattern)
    if ($found.Count -eq 0) { return '' }
    return $found[$found.Count - 1].Groups[2].Value
}

function Test-GhPermitted($ghArgs) {
    if ($ghArgs -match $GhGraphqlPattern) { return $false }
    if ($ghArgs -match $GhPermittedWritePattern) { return $true }

    $method = Find-GhMethod $ghArgs
    if ($method -and $method -notin $GhReadMethods) { return $false }
    if (-not $method -and $ghArgs -match $GhFieldPattern) { return $false }

    return $ghArgs -match $GhReadOnlyPattern
}

# Cuts the body of every heredoc that is data or a script, keeping the opener line. A heredoc with no
# closing line is kept whole, so a stray << can never hide the rest of the command.
function Remove-DataHeredocs($command) {
    $kept = [System.Collections.Generic.List[string]]::new()
    $delimiter = ''
    $keepBody = $false
    $body = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $command -split '\r?\n') {
        if ($delimiter) {
            $body.Add($line)
            if ($line -match ('^[ \t]*' + $delimiter + '[ \t]*$')) {
                if ($keepBody) { $kept.AddRange($body) }
                $delimiter = ''
            }
            continue
        }

        $kept.Add($line)
        $opener = [regex]::Match($line, $HeredocOpener)
        if ($opener.Success) {
            $delimiter = $opener.Groups[1].Value
            $keepBody = $line -notmatch $HeredocDataConsumers -or $line -match $HeredocShellWords
            $body.Clear()
        }
    }

    if ($delimiter) { $kept.AddRange($body) }
    return $kept -join "`n"
}

function Test-Backgrounds($command) {
    if ($command -match $BackgroundLauncherPattern) { return $true }
    if ($command -match $StartProcessPattern -and $command -notmatch $StartProcessWaitPattern) { return $true }

    $ampersandText = [regex]::Replace(($command -replace '\r?\n', ';'), $QuoteStripPattern, '${1} ')
    if ($ampersandText -match $WaitStatementPattern) { return $false }

    $ampersandText = ($ampersandText -replace $AmpersandNotBackground, ' ') -replace $AmpersandCallOperator, '$1 '
    return $ampersandText -match $BackgroundAmpersandPattern
}

# The invocation text ends at an ampersand, so `gh 2>&1 pr merge 5` would be read as a bare `gh 2>`.
# Joining the redirection keeps the whole argument list in view.
function Test-GhInvocationsPermitted($command) {
    $invocations = [regex]::Matches(($command -replace '>&', '>'), $GhInvocationPattern, 'IgnoreCase')
    foreach ($invocation in $invocations) {
        if (-not (Test-GhPermitted $invocation.Groups[2].Value)) { return $false }
    }
    return $true
}

function Get-GateDecision($commandText) {
    $command = Remove-DataHeredocs $commandText

    if (($command -creplace $SshPlainFilePattern, ' ') -match $SshDirPattern) {
        return @{ decision = 'deny'; reason = $ReasonSsh }
    }

    if ($command -match $GitApplyIndexPattern) {
        return @{ decision = 'deny'; reason = $ReasonGitApply }
    }

    if (($command -replace $GitReadPattern, ' ') -match $GitWritePattern) {
        return @{ decision = 'deny'; reason = $ReasonGit }
    }

    if ($command -match $SudoPattern) {
        return @{ decision = 'deny'; reason = $ReasonSudo }
    }

    if (Test-Backgrounds $command) {
        return @{ decision = 'deny'; reason = $ReasonBackground }
    }

    if (-not (Test-GhInvocationsPermitted $command)) {
        return @{ decision = 'deny'; reason = $ReasonGh }
    }

    return @{ decision = 'allow'; reason = $ReasonAllow }
}

function Invoke-Gate {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $result = Get-GateDecision ([string]$request.tool_input.command)
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
