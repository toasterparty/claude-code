# PreToolUse gate (Windows): auto-approve every tool call except the policy denials below.
# Bash allow rules are matched against literal command text, so a generated command using shell
# variables or substitution falls through them and prompts; deciding here bypasses that matcher.
# permissions.deny in settings.json is kept as the fallback for when this hook fails to run.
#
# Policy lives in the constants below and is mirrored in permission-gate.sh; test/run-gate-tests.ps1
# and its .sh twin assert both against the same cases.
param(
    # Load the policy without reading stdin, which is how the tests drive it.
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'

# A gated word counts wherever it is not part of a longer word, on both sides, so quoting
# (bash -c '...'), substitution (backticks) and paths (/usr/bin/gh) cannot smuggle one past the
# patterns. Anchoring on delimiters instead would miss every quoted and substituted form.
$WordStart = '(^|[^\w-])'
$WordEnd = '([^\w-]|$)'

# Anything that can move the index, HEAD, a ref, the working tree or the repository config. The
# arguments that may stand between git and its subcommand, such as -C <path>, exclude the command
# separators, so the command after a separator is never read as an argument of the git before it.
$Blank = '[ \t]'
$GitArg = '[^;&|)\s]'
$GitArgs = '(' + $Blank + '+' + $GitArg + '+)*'
$GitWriteVerbs = 'add|stage|rm|mv|restore|commit|push|pull|merge|rebase|cherry-pick|revert|am|apply' +
    '|stash|reset|checkout|clean|switch|branch|tag|remote|config' +
    '|submodule|worktree|notes|replace|reflog|gc|prune|filter-branch' +
    '|fast-import|sparse-checkout|bisect|update-index|update-ref|symbolic-ref'
$GitWritePattern = $WordStart + 'git(\.exe)?' + $GitArgs + $Blank + '+(' + $GitWriteVerbs + ')' + $WordEnd

# Applying a patch only rewrites working tree files, which the user can review and revert like any
# other edit, so it is left open. These flags are the exception: they move the index, and --3way
# reaches for the index too unless it is told to stay in the cache.
$GitApplyIndexFlags = '--index|--cached|--3way|-3'
$GitApplyIndexPattern = $WordStart + 'git(\.exe)?' + $GitArgs + $Blank + '+apply(' + $Blank + '+' + $GitArg + '+)*' +
    $Blank + '+(' + $GitApplyIndexFlags + ')' + $WordEnd

# Shapes cut from the command text before the write check above, so a verb that names both a read and
# a write is denied only in its write form. Worktree creation is among them because it leaves the
# index, HEAD and the working tree untouched. Quotes stay out of the arguments here, so a commit
# message quoting one of these shapes cannot clear the commit that carries it.
$GitSafeArg = '[^;&|)''"`\s]'
$GitSafeArgs = '(' + $Blank + '+' + $GitSafeArg + '+)*'
$GitReadShapes = 'worktree' + $Blank + '+(add|list)' +
    # The short listing flags cluster (-avv), and none of the write flags share a letter with them.
    '|branch' + $Blank + '+(-[avrl]+|--list|--all|--remotes|--verbose|--show-current|--contains|--merged|--no-merged|--points-at|--format|--sort)' +
    '|tag' + $Blank + '+(-l|-n[0-9]*|--list|--contains|--points-at|--format|--sort)' +
    '|remote' + $Blank + '+(-v|--verbose|show|get-url)' +
    '|config' + $Blank + '+(--get[a-zA-Z-]*|--list|-l)' +
    '|submodule' + $Blank + '+(status|summary)|notes' + $Blank + '+(list|show)' +
    '|reflog' + $Blank + '+show|stash' + $Blank + '+(list|show)' +
    # apply reaches no further than the working tree once its index flags are ruled out above.
    '|apply' +
    '|bisect' + $Blank + '+(log|view|visualize)'
# A subcommand given nothing to act on only lists, except stash, whose bare form stashes.
$GitListVerbs = 'branch|tag|remote|worktree|submodule|notes|reflog'
$GitReadPattern = $WordStart + 'git(\.exe)?' + $GitSafeArgs + $Blank + '+((' + $GitReadShapes + ')' + $WordEnd +
    '|(' + $GitListVerbs + ')' + $Blank + '*($|[;&|)\r\n]))'

$SudoPattern = $WordStart + 'sudo' + $WordEnd

# Backgrounding from inside the shell hides the process from the harness: the next tool call gets a
# new shell, so the process runs on with nothing to report its exit and no task for TaskOutput or
# TaskStop to reach. The run_in_background parameter covers every case this does, and being denied
# here costs one call where an escaped background process costs the whole run.
$BackgroundLaunchers = 'nohup|disown|setsid|start-job|start-threadjob'
$BackgroundLauncherPattern = $WordStart + '(' + $BackgroundLaunchers + ')' + $WordEnd
# Start-Process detaches unless it is told to wait for what it started. Invoke-Item stays open as the
# way to hand a file to its default application.
$StartProcessPattern = $WordStart + 'start-process' + $WordEnd
$StartProcessWaitPattern = $WordStart + '-wait' + $WordEnd
# The ampersands that redirect or chain, cut before the background operator is looked for.
$AmpersandNotBackground = '&&|&>>|&>|>&|<&|\|&'
# An ampersand opening a statement is PowerShell's call operator, which runs its command in the
# foreground; a background ampersand never opens one.
$AmpersandCallOperator = '(^|[;(|{&])' + $Blank + '*&'
# What is left backgrounds only where it stands as its own token, which is what tells it apart from
# the ampersands inside a URL query string or a quoted name.
$BackgroundAmpersandPattern = $Blank + '&'

# gh is inverted: only these read-only shapes pass, everything else is a denial.
$GhInvocationPattern = $WordStart + 'gh\s+([^;&|)]*)'
$GhBareReads = 'status|version|help|search|api'
$GhReadVerbs = 'view|list|ls|diff|checks|status|watch|download|clone|verify'
$GhReadOnlyPattern = '^(' + $GhBareReads + ')' + $WordEnd + '|^\S+\s+(' + $GhReadVerbs + ')' + $WordEnd
# Driving CI destroys nothing durable - a cancelled or rerun job can be dispatched again - so these
# are permitted despite being writes. They carry workflow inputs as field flags, so they are matched
# before the field check.
$GhPermittedWriteVerbs = 'rerun|cancel'
$GhPermittedWritePattern = '^workflow\s+run' + $WordEnd + '|^run\s+(' + $GhPermittedWriteVerbs + ')' + $WordEnd
# A read query and a mutation are the same request shape, and -F query=@file puts the deciding text
# out of reach of this hook, so the whole graphql endpoint stays denied.
$GhGraphqlPattern = 'graphql'
# gh api sends POST the moment a field flag appears, so a field flag is a write unless the method
# says otherwise. Any explicitly named method other than these is a write on its own.
$GhMethodPattern = '(-X|--method)[\s=]*([A-Za-z]+)'
$GhFieldPattern = '(^|\s)(-f|-F|--field|--raw-field|--input)(\s|=|$)'
$GhReadMethods = @('GET', 'HEAD')

$ReasonAllow = 'Auto-approved by permission-gate.'
$ReasonGit = 'Commands that alter git state are reserved for the user.'
$ReasonGitApply = 'git apply may not stage what it applies; drop --index, --cached and --3way.'
$ReasonSudo = 'Elevation is not permitted.'
$ReasonGh = 'Only read-only gh queries and CI dispatch are permitted.'
$ReasonBackground = 'Background work belongs in the run_in_background parameter, not in the shell.'

# Method named by the last -X/--method flag in the arguments, empty when none is given.
function Get-GhMethod($ghArgs) {
    $found = [regex]::Matches($ghArgs, $GhMethodPattern)
    if ($found.Count -eq 0) { return '' }
    return $found[$found.Count - 1].Groups[2].Value.ToUpperInvariant()
}

function Test-GhPermitted($ghArgs) {
    if ($ghArgs -match $GhGraphqlPattern) { return $false }
    if ($ghArgs -match $GhPermittedWritePattern) { return $true }

    $method = Get-GhMethod $ghArgs
    $readMethod = $method -in $GhReadMethods
    if ($method -and -not $readMethod) { return $false }
    if (-not $readMethod -and $ghArgs -match $GhFieldPattern) { return $false }

    return $ghArgs -match $GhReadOnlyPattern
}

function Test-Backgrounds($command) {
    if ($command -match $BackgroundLauncherPattern) { return $true }
    if ($command -match $StartProcessPattern -and $command -notmatch $StartProcessWaitPattern) { return $true }

    $ampersandText = ($command -replace $AmpersandNotBackground, ' ') -replace $AmpersandCallOperator, '$1 '
    return $ampersandText -match $BackgroundAmpersandPattern
}

function Test-GhInvocationsPermitted($command) {
    foreach ($invocation in [regex]::Matches($command, $GhInvocationPattern)) {
        if (-not (Test-GhPermitted $invocation.Groups[2].Value)) { return $false }
    }
    return $true
}

function Get-GateDecision($command) {
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
    $command = if ($request.tool_input -and $request.tool_input.PSObject.Properties['command']) { [string]$request.tool_input.command } else { '' }
    $result = Get-GateDecision $command
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
