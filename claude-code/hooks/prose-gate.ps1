# PreToolUse gate (Windows): deny a prose write until english.md is in context. The instruction to
# read it is a precondition on a category the model has to classify for itself while it is busy
# composing, which it misses often enough to need enforcing here. A denial is self-healing: the
# model reads the file and retries, so the cost is one blocked call per session.
#
# Scope is markdown plus everything under .agent/outbox/. Source files are out: gating them would
# block the first mechanical edit of every session for the sake of the occasional comment.
#
# Policy lives in the constants below and is mirrored in prose-gate.sh; test/run-prose-gate-tests.ps1
# and its .sh twin assert both against the same cases.
param(
    # Load the policy without reading stdin, which is how the tests drive it.
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'

$ProsePathPattern = '(\.md$|(^|/)\.agent/outbox/)'
# Read, Write and Edit are the only tools whose input carries file_path, and each of them leaves the
# file in context, so any of the three counts. Glob and Grep name their target `path` and do not.
$EnglishReadPattern = '"file_path":"[^"]*english\.md"'

$ReasonUnread = 'Read languages/english.md (beside CLAUDE.md in the Claude home directory) before writing prose that outlives the session, then retry this write.'

function Get-ProseGateDecision($filePath, $englishInContext) {
    if ($englishInContext) { return @{ decision = 'allow'; reason = '' } }

    # The twin runs against POSIX paths, so both hooks compare one separator.
    $normalized = ([string]$filePath).Replace('\', '/')
    if ($normalized -match $ProsePathPattern) { return @{ decision = 'deny'; reason = $ReasonUnread } }

    return @{ decision = 'allow'; reason = '' }
}

# True when the session transcript at $transcriptPath shows english.md passing through a file tool.
# An unreadable transcript is true as well: failing open costs a missed reminder, where failing
# closed would deny every prose write for the rest of the session and leave the retry no way to
# succeed.
function Test-EnglishMdInContext($transcriptPath) {
    if (-not $transcriptPath -or -not (Test-Path -LiteralPath $transcriptPath)) { return $true }
    return [bool](Select-String -LiteralPath $transcriptPath -Pattern $EnglishReadPattern -Quiet)
}

function Invoke-ProseGate {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $filePath = if ($request.tool_input -and $request.tool_input.PSObject.Properties['file_path']) { [string]$request.tool_input.file_path } else { '' }
    $transcript = if ($request.PSObject.Properties['transcript_path']) { [string]$request.transcript_path } else { '' }

    $result = Get-ProseGateDecision $filePath (Test-EnglishMdInContext $transcript)
    # Only the denial is a decision. Staying silent on allow leaves the write to the permission flow
    # it would have gone through anyway, rather than making this hook a second approval authority.
    if ($result.decision -ne 'deny') { return }

    $payload = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $result.reason
        }
    }
    [Console]::Out.Write((ConvertTo-Json $payload -Depth 5 -Compress))
}

if (-not $LibraryOnly) {
    Invoke-ProseGate
}
