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

$GitWriteVerbs = 'add|stage|restore|commit|push|stash|reset|checkout|clean|switch'
$GitWritePattern = $WordStart + 'git(\s+\S+)*\s+(' + $GitWriteVerbs + ')' + $WordEnd
$SudoPattern = $WordStart + 'sudo' + $WordEnd

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
$ReasonSudo = 'Elevation is not permitted.'
$ReasonGh = 'Only read-only gh queries and CI dispatch are permitted.'

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

function Test-GhInvocationsPermitted($command) {
    foreach ($invocation in [regex]::Matches($command, $GhInvocationPattern)) {
        if (-not (Test-GhPermitted $invocation.Groups[2].Value)) { return $false }
    }
    return $true
}

function Get-GateDecision($command) {
    if ($command -match $GitWritePattern) {
        return @{ decision = 'deny'; reason = $ReasonGit }
    }

    if ($command -match $SudoPattern) {
        return @{ decision = 'deny'; reason = $ReasonSudo }
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
