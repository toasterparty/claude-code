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

function Test-LinesHoldEnglish($lines, $sentinel) {
    if ($sentinel -and ($lines | Select-String -SimpleMatch $sentinel -Quiet)) { return $true }
    return [bool]($lines | Select-String -Pattern $EnglishReadPattern -Quiet)
}

# The parent transcript's lines up to the message a fork branched at, which is the context the fork
# inherited without copying it into its own sidechain. Empty unless the sidechain is a fork's.
function Get-ForkInheritedLines($sidechainPath, $transcriptPath) {
    $ref = try { Get-Content -LiteralPath $sidechainPath -TotalCount 1 | ConvertFrom-Json } catch { $null }
    if (-not $ref -or $ref.type -ne 'fork-context-ref' -or -not $ref.parentLastUuid) { return @() }

    $branchPoint = '"uuid":"' + $ref.parentLastUuid + '"'
    $inherited = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -LiteralPath $transcriptPath) {
        $inherited.Add($line)
        if ($line.Contains($branchPoint)) { break }
    }
    return $inherited
}

# True when the calling context holds english.md's text or a file tool call on it. A subagent's
# call carries its parent's transcript_path plus its agent_id, and its own messages land in a
# sidechain transcript beside the parent's. An unreadable transcript is true as well: failing open
# costs a missed reminder, where failing closed would deny every prose write for the rest of the
# session.
function Test-EnglishMdInContext($transcriptPath, $sentinel, $agentId) {
    if (-not $transcriptPath -or -not (Test-Path -LiteralPath $transcriptPath)) { return $true }
    if (-not $agentId) { return Test-LinesHoldEnglish (Get-Content -LiteralPath $transcriptPath) $sentinel }

    $sidechain = ($transcriptPath -replace '\.jsonl$', '') + "/subagents/agent-$agentId.jsonl"
    if (-not (Test-Path -LiteralPath $sidechain)) { return $true }
    if (Test-LinesHoldEnglish (Get-Content -LiteralPath $sidechain) $sentinel) { return $true }
    return Test-LinesHoldEnglish (Get-ForkInheritedLines $sidechain $transcriptPath) $sentinel
}

function Get-DenialReason($englishText) {
    if (-not $englishText) { return $ReasonUnread }
    return "$ReasonInline`n`n$englishText"
}

function Invoke-ProseGate {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $filePath = if ($request.tool_input -and $request.tool_input.PSObject.Properties['file_path']) { [string]$request.tool_input.file_path } else { '' }
    $englishText = try { Get-Content -LiteralPath $EnglishPath -Raw -ErrorAction Stop } catch { '' }
    $inContext = Test-EnglishMdInContext ([string]$request.transcript_path) (Get-EnglishSentinel $englishText) ([string]$request.agent_id)

    $result = Get-ProseGateDecision $filePath $inContext
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
