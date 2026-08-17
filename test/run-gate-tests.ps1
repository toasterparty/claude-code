# Asserts permission-gate.ps1 against test/gate-cases.tsv. Run run-gate-tests.sh for the .sh twin.
$ErrorActionPreference = 'Stop'

$TopDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $TopDir 'claude-code\hooks\permission-gate.ps1') -LibraryOnly

$total = 0
$failed = 0
foreach ($line in Get-Content (Join-Path $PSScriptRoot 'gate-cases.tsv')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }

    $fields = $line -split "`t", 2
    $expected = $fields[0].Trim()
    $command = if ($fields.Count -gt 1) { $fields[1] } else { '' }

    $total++
    $actual = (Get-GateDecision $command).decision
    if ($actual -ne $expected) {
        $failed++
        "FAIL expected=$expected actual=$actual : $command"
    }
}

"$($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
