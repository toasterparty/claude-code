# Asserts code-reminder.ps1 against test/code-reminder-cases.tsv and the fixtures below.
# Run run-code-reminder-tests.sh for the .sh twin.
$ErrorActionPreference = 'Stop'

$TopDir = Split-Path -Parent $PSScriptRoot
$Hook = Join-Path $TopDir 'claude-code\hooks\code-reminder.ps1'
. $Hook -LibraryOnly

$total = 0
$failed = 0

function Test-Case($expected, $actual, $label) {
    $script:total++
    if ($actual -ne $expected) {
        $script:failed++
        "FAIL expected=$expected actual=$actual : $label"
    }
}

foreach ($line in Get-Content (Join-Path $PSScriptRoot 'code-reminder-cases.tsv')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }

    $fields = $line -split "`t", 4
    $expected = $fields[0].Trim()
    $reminded = [int]$fields[1]
    $inContext = [int]$fields[2]
    $filePath = if ($fields.Count -gt 3) { $fields[3] } else { '' }

    $actual = Get-CodeReminderDecision $filePath ($reminded -eq 1) ($inContext -eq 1)
    Test-Case $expected $actual "reminded=$reminded in_context=$inContext $(if ($filePath) { $filePath } else { '<no file path>' })"
}

$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $fixtureDir | Out-Null
try {
    Test-Case 'session-a' (Get-MarkerName 'session-a' '') 'top-level session is marked by its id'
    Test-Case 'session-a-sub' (Get-MarkerName 'session-a' 'sub') 'subagent is marked apart from its parent'
    Test-Case $true (Test-Reminded (Join-Path $fixtureDir 'markers') '') 'context without an id counts as reminded'

    # The hook end to end: a PostToolUse request on stdin, the reminder or nothing on stdout. TMP
    # points the hook's marker directory into the fixture.
    $read = (Join-Path $fixtureDir 'read.jsonl').Replace('\', '/')
    $unread = (Join-Path $fixtureDir 'unread.jsonl').Replace('\', '/')
    $missing = (Join-Path $fixtureDir 'missing.jsonl').Replace('\', '/')
    Set-Content -LiteralPath $read '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/home/u/.claude/languages/common.md"}}]}}'
    Set-Content -LiteralPath $unread '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/repo/README.md"}}]}}'
    $text = (Join-Path $fixtureDir 'text.jsonl').Replace('\', '/')
    Set-Content -LiteralPath $text ('{"type":"user","message":{"content":"' + (Get-CommonSentinel) + '"}}')
    New-Item -ItemType Directory -Force -Path (Join-Path $fixtureDir 'unread\subagents') | Out-Null
    Copy-Item -LiteralPath $read (Join-Path $fixtureDir 'unread\subagents\agent-sub.jsonl')

    $savedTmp = $env:TMP
    $env:TMP = $fixtureDir
    try {
        $requests = @(
            @{ json = '{"session_id":"e2e-a","transcript_path":"' + $unread + '","tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $true; label = 'first code edit with common.md unread reminds' }
            @{ json = '{"session_id":"e2e-a","transcript_path":"' + $unread + '","tool_input":{"file_path":"/repo/src/other.c"}}'; remind = $false; label = 'second code edit is silent' }
            @{ json = '{"session_id":"e2e-b","transcript_path":"' + $read + '","tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $false; label = 'code edit with common.md read is silent' }
            @{ json = '{"session_id":"e2e-e","transcript_path":"' + $text + '","tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $false; label = 'code edit with common.md text in context is silent' }
            @{ json = '{"session_id":"e2e-c","transcript_path":"' + $unread + '","agent_id":"sub","tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $false; label = 'subagent that read common.md is silent' }
            @{ json = '{"session_id":"e2e-c","transcript_path":"' + $unread + '","tool_input":{"file_path":"/repo/README.md"}}'; remind = $false; label = 'prose edit is silent' }
            @{ json = '{"session_id":"e2e-d","transcript_path":"' + $missing + '","tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $false; label = 'unreadable transcript is silent' }
        )
        foreach ($request in $requests) {
            $output = ($request.json | pwsh -NoProfile -File $Hook) -join ''
            $context = if ($output) { ($output | ConvertFrom-Json).hookSpecificOutput.additionalContext } else { '' }
            Test-Case $request.remind ($context -eq $Reminder) "end to end: $($request.label)"
        }
    }
    finally {
        $env:TMP = $savedTmp
    }
}
finally {
    Remove-Item -Recurse -Force $fixtureDir
}

"$($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
