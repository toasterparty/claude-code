# Asserts agenda-reminder.ps1 against test/agenda-reminder-cases.tsv and the marker fixture below.
# Run run-agenda-reminder-tests.sh for the .sh twin.
$ErrorActionPreference = 'Stop'

$TopDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $TopDir 'claude-code\hooks\agenda-reminder.ps1') -LibraryOnly

$total = 0
$failed = 0

function Test-Case($expected, $actual, $label) {
    $script:total++
    if ($actual -ne $expected) {
        $script:failed++
        "FAIL expected=$expected actual=$actual : $label"
    }
}

foreach ($line in Get-Content (Join-Path $PSScriptRoot 'agenda-reminder-cases.tsv')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }

    $fields = $line -split "`t", 4
    $expected = $fields[0].Trim()
    $isSubagent = [int]$fields[1]
    $reminded = [int]$fields[2]
    $filePath = if ($fields.Count -gt 3) { $fields[3] } else { '' }

    $actual = Get-AgendaReminderDecision $filePath ($isSubagent -eq 1) ($reminded -eq 1)
    Test-Case $expected $actual "subagent=$isSubagent reminded=$reminded $(if ($filePath) { $filePath } else { '<no file path>' })"
}

$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $fixtureDir | Out-Null
try {
    $markerDir = Join-Path $fixtureDir 'markers'

    Test-Case $false (Test-Reminded $markerDir 'session-a') 'new session is not yet reminded'
    Save-Reminded $markerDir 'session-a'
    Test-Case $true (Test-Reminded $markerDir 'session-a') 'session stays reminded once saved'
    Test-Case $false (Test-Reminded $markerDir 'session-b') 'another session is unaffected'
    Test-Case $true (Test-Reminded $markerDir '') 'session without an id counts as reminded'
    Test-Case $true (Test-Reminded $markerDir '../escape') 'session id that is not a safe file name counts as reminded'

    # The hook end to end: a PostToolUse request on stdin, the reminder or nothing on stdout. TMP
    # points the hook's marker directory into the fixture.
    $savedTmp = $env:TMP
    $env:TMP = $fixtureDir
    try {
        $hook = Join-Path $TopDir 'claude-code\hooks\agenda-reminder.ps1'
        $requests = @(
            @{ json = '{"session_id":"e2e-a","tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $true; label = 'first project edit reminds' }
            @{ json = '{"session_id":"e2e-a","tool_input":{"file_path":"/repo/src/other.c"}}'; remind = $false; label = 'second project edit is silent' }
            @{ json = '{"session_id":"e2e-b","tool_input":{"file_path":"/repo/.agent/doc/agenda.md"}}'; remind = $false; label = 'agent file edit is silent' }
            @{ json = '{"session_id":"e2e-b","tool_input":{"notebook_path":"/repo/nb.ipynb"}}'; remind = $true; label = 'notebook edit reminds' }
            @{ json = '{"session_id":"e2e-c","agent_id":"sub","tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $false; label = 'subagent edit is silent' }
            @{ json = '{"session_id":"e2e-c","agent_id":"","tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $true; label = 'empty agent_id is the top-level session' }
            @{ json = '{"tool_input":{"file_path":"/repo/src/main.c"}}'; remind = $false; label = 'edit without a session id is silent' }
            @{ json = '{}'; remind = $false; label = 'empty request is silent' }
        )
        foreach ($request in $requests) {
            $output = $request.json | pwsh -NoProfile -File $hook
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
