# PostToolUse hook (Windows): remind a context once, after it edits a code file, to read
# languages/common.md and the language's own file when common.md is not yet in context. A reminder
# rather than a gate like prose-gate, because the first edit of a session is often a one-line fix that
# the rules would not change.
#
# Every change here is mirrored in code-reminder.sh, and test/code-reminder-cases.tsv must pass on both.
param(
    # Load the policy without reading stdin, which is how the tests drive it.
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'

$CodePathPattern = '(\.(sh|bash|ps1|psm1|py|c|h|cc|cpp|hpp|rs|ts|tsx|js|jsx|mjs|cjs|go|java|kt|cs|rb|lua|swift|zig|mk)|(^|/)(GNU)?[Mm]akefile)$'
# Read, Write and Edit are the tools whose input carries file_path, and each leaves the file in context.
$CommonReadPattern = '"file_path":"[^"]*common\.md"'
$CommonPath = Join-Path $PSScriptRoot '..\languages\common.md'

$Reminder = 'This context edited a code file without languages/common.md in context. Before further code edits, read languages/common.md and the language''s own file among languages/{bash,c,make,python}.md where one exists (beside CLAUDE.md in the Claude home directory), as CLAUDE.md''s AI Rules require. This reminder appears once per context.'

$MarkerDir = Join-Path ([System.IO.Path]::GetTempPath()) 'claude-code-reminder'
$MarkerNamePattern = '^[A-Za-z0-9_-]+$'

# Returns remind or skip.
function Get-CodeReminderDecision($filePath, $isReminded, $commonInContext) {
    if ($isReminded -or $commonInContext) { return 'skip' }

    # The twin runs against POSIX paths, so both hooks compare one separator.
    $normalized = ([string]$filePath).Replace('\', '/')
    if ($normalized -cmatch $CodePathPattern) { return 'remind' }
    return 'skip'
}

# A subagent's context is its own, so it is marked apart from its parent session.
function Get-MarkerName($sessionId, $agentId) {
    if ($agentId) { return "$sessionId-$agentId" }
    return [string]$sessionId
}

# A marker name that is not a safe file name cannot be saved, so it counts as reminded: staying
# silent costs one missed reminder, where reminding would repeat on every edit.
function Test-Reminded($markerDir, $markerName) {
    if ($markerName -cnotmatch $MarkerNamePattern) { return $true }
    return Test-Path -LiteralPath (Join-Path $markerDir $markerName)
}

function Save-Reminded($markerDir, $markerName) {
    New-Item -ItemType Directory -Force -Path $markerDir | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $markerDir $markerName) | Out-Null
}

# The first body line of common.md, cut before any character JSON escapes, so it appears verbatim in
# the transcript wherever the file's text does.
function Get-CommonSentinel {
    $text = try { Get-Content -LiteralPath $CommonPath -Raw -ErrorAction Stop } catch { '' }
    foreach ($line in ([string]$text -split "`r?`n")) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        return ($line -split '["\\]', 2)[0]
    }
    return ''
}

# True when the calling context's transcript holds common.md's text or a file tool call on it. A
# subagent's messages land in a sidechain transcript beside its parent's. An unreadable transcript
# counts as in context, so a broken lookup never repeats the reminder.
function Test-CommonMdInContext($transcriptPath, $agentId, $sentinel) {
    if ($agentId) { $transcriptPath = ($transcriptPath -replace '\.jsonl$', '') + "/subagents/agent-$agentId.jsonl" }
    if (-not $transcriptPath -or -not (Test-Path -LiteralPath $transcriptPath)) { return $true }

    $patterns = @($CommonReadPattern)
    if ($sentinel) { $patterns += [regex]::Escape($sentinel) }
    return [bool](Select-String -LiteralPath $transcriptPath -Pattern $patterns -Quiet)
}

function Invoke-CodeReminder {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $filePath = [string]$request.tool_input.file_path
    $agentId = [string]$request.agent_id
    $markerName = Get-MarkerName ([string]$request.session_id) $agentId

    $isReminded = Test-Reminded $MarkerDir $markerName
    $inContext = (-not $isReminded) -and (Test-CommonMdInContext ([string]$request.transcript_path) $agentId (Get-CommonSentinel))
    if ((Get-CodeReminderDecision $filePath $isReminded $inContext) -ne 'remind') { return }

    Save-Reminded $MarkerDir $markerName
    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'PostToolUse'
            additionalContext = $Reminder
        }
    }
    [Console]::Out.Write((ConvertTo-Json $payload -Depth 5 -Compress))
}

if (-not $LibraryOnly) {
    Invoke-CodeReminder
}
