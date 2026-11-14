# PostToolUse hook (Windows): remind the session once, after its first edit to a project file, to
# update the agenda before it reports the task done. A reminder rather than a gate: the hook cannot
# tell whether the edit changed anything open, and a blocked stop would cost a turn every time it
# had not.
#
# Every change here is mirrored in agenda-reminder.sh, and test/agenda-reminder-cases.tsv must pass on both.
param(
    # Load the policy without reading stdin, which is how the tests drive it.
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'

# The agent's own working files, the agenda among them, are not project work.
$AgentDirPattern = '(^|/)\.agent/'

$Reminder = 'This session has now edited project files. Before reporting the task done, update the project agenda as the user CLAUDE.md describes. This reminder appears once per session.'

$MarkerDir = Join-Path ([System.IO.Path]::GetTempPath()) 'claude-agenda-reminder'
$SessionIdPattern = '^[A-Za-z0-9_-]+$'

# Returns remind or skip. A subagent is skipped because only the top-level session edits the agenda.
function Get-AgendaReminderDecision($filePath, $isSubagent, $isReminded) {
    if ($isSubagent -or $isReminded) { return 'skip' }

    # The twin runs against POSIX paths, so both hooks compare one separator.
    $normalized = ([string]$filePath).Replace('\', '/')
    if ($normalized -match $AgentDirPattern) { return 'skip' }
    return 'remind'
}

# True once Save-Reminded has run for the session. A session without a usable id, one that is not a
# safe file name, cannot be marked, so it counts as reminded: staying silent costs one missed
# reminder, where reminding would repeat on every edit.
function Test-Reminded($markerDir, $sessionId) {
    if ($sessionId -cnotmatch $SessionIdPattern) { return $true }
    return Test-Path -LiteralPath (Join-Path $markerDir $sessionId)
}

function Save-Reminded($markerDir, $sessionId) {
    New-Item -ItemType Directory -Force -Path $markerDir | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $markerDir $sessionId) | Out-Null
}

function Invoke-AgendaReminder {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $filePath = [string]$request.tool_input.file_path
    if (-not $filePath) { $filePath = [string]$request.tool_input.notebook_path }
    $sessionId = [string]$request.session_id
    $isSubagent = [bool]$request.agent_id

    $decision = Get-AgendaReminderDecision $filePath $isSubagent (Test-Reminded $MarkerDir $sessionId)
    if ($decision -ne 'remind') { return }

    Save-Reminded $MarkerDir $sessionId
    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'PostToolUse'
            additionalContext = $Reminder
        }
    }
    [Console]::Out.Write((ConvertTo-Json $payload -Depth 5 -Compress))
}

if (-not $LibraryOnly) {
    Invoke-AgendaReminder
}
