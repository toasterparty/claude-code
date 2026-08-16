# PreToolUse gate (Windows): auto-approve every tool call except the policy denials below.
# Bash allow rules are matched against literal command text, so a generated command using shell
# variables or substitution falls through them and prompts; deciding here bypasses that matcher.
# permissions.deny in settings.json is kept as the fallback for when this hook fails to run.
$ErrorActionPreference = 'Stop'

$GitWritePattern = '(^|[\s;&|(])git(\s+\S+)*\s+(add|stage|restore|commit|push|stash|reset|checkout|clean|switch)(\s|$)'
$SudoPattern = '(^|[\s;&|(])sudo(\s|$)'

# gh is inverted: only these read-only shapes pass, everything else is a denial.
$GhInvocationPattern = '(^|[\s;&|(])gh\s+([^;&|)]*)'
$GhReadOnlyPattern = '^(status|version|help)(\s|$)|^search(\s|$)|^api(\s|$)|^\S+\s+(view|list|diff|checks|status|watch)(\s|$)'
# gh api sends POST the moment a field flag appears, with or without an explicit method.
$GhWritePattern = '(^|\s)(-f|-F|--field|--raw-field|--input)(\s|=|$)|(-X|--method)[\s=]+(POST|PUT|PATCH|DELETE)|graphql'

function Write-Decision($decision, $reason) {
    $payload = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $decision
            permissionDecisionReason = $reason
        }
    }
    [Console]::Out.Write((ConvertTo-Json $payload -Depth 5 -Compress))
    exit 0
}

function Test-GhReadOnly($ghArgs) {
    if ($ghArgs -match $GhWritePattern) { return $false }
    return $ghArgs -match $GhReadOnlyPattern
}

$request = [Console]::In.ReadToEnd() | ConvertFrom-Json
$command = if ($request.tool_input -and $request.tool_input.PSObject.Properties['command']) { [string]$request.tool_input.command } else { '' }

if ($command -match $GitWritePattern) {
    Write-Decision 'deny' 'Commands that alter git state are reserved for the user.'
}

if ($command -match $SudoPattern) {
    Write-Decision 'deny' 'Elevation is not permitted.'
}

foreach ($invocation in [regex]::Matches($command, $GhInvocationPattern)) {
    if (-not (Test-GhReadOnly $invocation.Groups[2].Value)) {
        Write-Decision 'deny' 'Only read-only gh queries are permitted.'
    }
}

Write-Decision 'allow' 'Auto-approved by permission-gate.'
