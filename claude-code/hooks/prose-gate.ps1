# PreToolUse gate (Windows): deny a prose write until english.md is in context. The instruction to
# read it is a precondition on a category the model has to classify for itself while it is busy
# composing, which it misses often enough to need enforcing here. The denial carries the file's full
# text and so puts it in context itself: the retry succeeds without a separate read, and the gate
# fires at most once per transcript.
#
# Scope is markdown plus everything under .agent/outbox/. Source files are out: gating them would
# block the first mechanical edit of every session for the sake of the occasional comment. The
# agent's own working notes under .agent/doc/ and .agent/scripts/ are exempt.
#
# Policy lives in the constants below and is mirrored in prose-gate.sh; test/run-prose-gate-tests.ps1
# and its .sh twin assert both against the same cases.
param(
    # Load the policy without reading stdin, which is how the tests drive it.
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'

$ProsePathPattern = '(\.md$|(^|/)\.agent/outbox/)'
$AgentExemptPattern = '(^|/)\.agent/(doc|scripts)/'
# Read, Write and Edit are the only tools whose input carries file_path, and each of them leaves the
# file in context, so any of the three counts. Glob and Grep name their target `path` and do not.
$EnglishReadPattern = '"file_path":"[^"]*english\.md"'
$EnglishPath = Join-Path $PSScriptRoot '..\languages\english.md'

$ReasonUnread = 'Read languages/english.md (beside CLAUDE.md in the Claude home directory) before writing prose that outlives the session, then retry this write.'
$ReasonInline = 'This write is prose that outlives the session, and languages/english.md (beside CLAUDE.md in the Claude home directory) is not in context yet. Its full text follows, so no separate read is needed: apply it, then retry this write.'

function Get-ProseGateDecision($filePath, $englishInContext) {
    if ($englishInContext) { return @{ decision = 'allow' } }

    # The twin runs against POSIX paths, so both hooks compare one separator.
    $normalized = ([string]$filePath).Replace('\', '/')
    if ($normalized -match $AgentExemptPattern) { return @{ decision = 'allow' } }
    if ($normalized -match $ProsePathPattern) { return @{ decision = 'deny' } }

    return @{ decision = 'allow' }
}

# The first body line of english.md, cut before any character JSON escapes, so it appears verbatim
# in the transcript wherever the file's text does: a Read result, a cat or Get-Content result, or
# this hook's own denial.
function Get-EnglishSentinel($englishText) {
    foreach ($line in ([string]$englishText -split "`r?`n")) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        return ($line -split '["\\]', 2)[0]
    }
    return ''
}

# True when the session transcript at $transcriptPath holds english.md's text or a file tool call on
# it. An unreadable transcript is true as well: failing open costs a missed reminder, where failing
# closed would deny every prose write for the rest of the session.
function Test-EnglishMdInContext($transcriptPath, $sentinel) {
    if (-not $transcriptPath -or -not (Test-Path -LiteralPath $transcriptPath)) { return $true }
    if ($sentinel -and (Select-String -LiteralPath $transcriptPath -SimpleMatch $sentinel -Quiet)) { return $true }
    return [bool](Select-String -LiteralPath $transcriptPath -Pattern $EnglishReadPattern -Quiet)
}

function Get-DenialReason($englishText) {
    if (-not $englishText) { return $ReasonUnread }
    return "$ReasonInline`n`n$englishText"
}

function Invoke-ProseGate {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $filePath = if ($request.tool_input -and $request.tool_input.PSObject.Properties['file_path']) { [string]$request.tool_input.file_path } else { '' }
    $transcript = if ($request.PSObject.Properties['transcript_path']) { [string]$request.transcript_path } else { '' }
    $englishText = try { Get-Content -LiteralPath $EnglishPath -Raw -ErrorAction Stop } catch { '' }

    $result = Get-ProseGateDecision $filePath (Test-EnglishMdInContext $transcript (Get-EnglishSentinel $englishText))
    # Only the denial is a decision. Staying silent on allow leaves the write to the permission flow
    # it would have gone through anyway, rather than making this hook a second approval authority.
    if ($result.decision -ne 'deny') { return }

    $payload = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = Get-DenialReason $englishText
        }
    }
    [Console]::Out.Write((ConvertTo-Json $payload -Depth 5 -Compress))
}

if (-not $LibraryOnly) {
    Invoke-ProseGate
}
