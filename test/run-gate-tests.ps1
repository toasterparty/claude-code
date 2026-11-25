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
    @{ json = '{"tool_input":{"command":"sudo ls"}}'; decision = 'deny'; reason = $ReasonSudo }
    @{ json = '{"tool_input":{}}'; decision = 'allow'; reason = $ReasonAllow }
    @{ json = '{}'; decision = 'allow'; reason = $ReasonAllow }
    @{ json = '{"tool_name":"Bash","tool_input":{"command":"rm -rf $W"}}'; decision = 'deny'; reason = $ReasonRm }
    @{ json = '{"tool_name":"Bash","tool_input":{"command":"rm -rf ${W:?}/x"}}'; decision = 'allow'; reason = $ReasonAllow }
    @{ json = '{"tool_name":"PowerShell","tool_input":{"command":"rm -rf ${W:?}/x"}}'; decision = 'deny'; reason = $ReasonRmPowerShell }
    @{ json = '{"tool_name":"PowerShell","tool_input":{"command":"Remove-Item -Recurse $W"}}'; decision = 'allow'; reason = $ReasonAllow }
    @{ json = '{"tool_name":"Bash","tool_input":{"command":"until curl -s localhost:5198; do sleep 1; done"}}'; decision = 'deny'; reason = $ReasonPollLoop }
    @{ json = '{"tool_name":"Bash","tool_input":{"command":"until curl -s localhost:5198; do sleep 1; done","run_in_background":true}}'; decision = 'allow'; reason = $ReasonAllow }
    @{ json = '{"tool_name":"Monitor","tool_input":{"command":"while true; do gh run list; sleep 30; done"}}'; decision = 'allow'; reason = $ReasonAllow }
    @{ json = '{"tool_name":"PowerShell","tool_input":{"command":"while (-not (Test-Path out.txt)) { Start-Sleep 1 }"}}'; decision = 'deny'; reason = $ReasonPollLoop }
    @{ json = '{"tool_name":"Bash","tool_input":{"command":"grep -n ''while sleep'' notes.md"}}'; decision = 'allow'; reason = $ReasonAllow }
    @{ json = '{"tool_name":"Bash","tool_input":{"command":"for f in *.md; do wc -l $f; done"}}'; decision = 'allow'; reason = $ReasonAllow }
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
