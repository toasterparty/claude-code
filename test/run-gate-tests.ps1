# Asserts permission-gate.ps1 against test/gate-cases.tsv. Run run-gate-tests.sh for the .sh twin.
$ErrorActionPreference = 'Stop'

$TopDir = Split-Path -Parent $PSScriptRoot
$Hook = Join-Path $TopDir 'claude-code\hooks\permission-gate.ps1'
. $Hook -LibraryOnly

$total = 0
$failed = 0
foreach ($line in Get-Content (Join-Path $PSScriptRoot 'gate-cases.tsv')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }

    $fields = $line -split "`t", 2
    $expected = $fields[0].Trim()
    $command = if ($fields.Count -gt 1) { $fields[1] -replace '<NL>', "`n" } else { '' }

    $total++
    $actual = (Get-GateDecision $command).decision
    if ($actual -ne $expected) {
        $failed++
        "FAIL expected=$expected actual=$actual : $command"
    }
}

# The hook end to end: a PreToolUse request on stdin, its decision on stdout.
$requests = @(
    @{ json = '{"tool_input":{"command":"sudo ls"}}'; decision = 'deny'; reason = 'Elevation is not permitted.' }
    @{ json = '{"tool_input":{}}'; decision = 'allow'; reason = 'Auto-approved by permission-gate.' }
    @{ json = '{}'; decision = 'allow'; reason = 'Auto-approved by permission-gate.' }
)
foreach ($request in $requests) {
    $total++
    $output = ($request.json | pwsh -NoProfile -File $Hook | ConvertFrom-Json).hookSpecificOutput
    if ($output.hookEventName -ne 'PreToolUse' -or $output.permissionDecision -ne $request.decision -or
        $output.permissionDecisionReason -ne $request.reason) {
        $failed++
        "FAIL end to end: $($request.json)"
    }
}

"$($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
