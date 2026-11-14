# Asserts session-start.ps1 against test/session-start-cases.tsv and the fixtures below.
# Run run-session-start-tests.sh for the .sh twin.
$ErrorActionPreference = 'Stop'

$TopDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $TopDir 'claude-code\hooks\session-start.ps1') -LibraryOnly

$total = 0
$failed = 0

function Test-Case($expected, $actual, $label) {
    $script:total++
    if ([string]$actual -ne [string]$expected) {
        $script:failed++
        "FAIL expected=$expected actual=$actual : $label"
    }
}

function ConvertFrom-Dash($field) {
    if ($field -eq '-') { return '' }
    return $field
}

foreach ($line in Get-Content (Join-Path $PSScriptRoot 'session-start-cases.tsv')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }

    $fields = $line -split "`t", 3
    $deployed = ConvertFrom-Dash $fields[0]
    $latest = ConvertFrom-Dash $fields[1]
    $expected = ConvertFrom-Dash $fields[2]
    Test-Case $expected (Get-DriftMessage $deployed $latest) "deployed=$($fields[0]) latest=$($fields[1])"
}

$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path (Join-Path $fixtureDir 'with\.agent'), (Join-Path $fixtureDir 'without') | Out-Null
try {
    Set-Content -LiteralPath (Join-Path $fixtureDir 'with\.agent\AGENTS.md') -Value 'memory'

    Test-Case (Join-Path (Join-Path $fixtureDir 'with') '.agent/AGENTS.md') (Find-ProjectMemory (Join-Path $fixtureDir 'with')) 'directory holding .agent/AGENTS.md'
    Test-Case '' (Find-ProjectMemory (Join-Path $fixtureDir 'without')) 'directory without .agent/AGENTS.md'
}
finally {
    Remove-Item -Recurse -Force $fixtureDir
}

foreach ($source in 'startup', 'clear', 'compact') {
    Test-Case $true ($source -match $MemorySources) "memory loads on $source"
}
Test-Case $false ('resume' -match $MemorySources) 'memory skips resume'
Test-Case $true ('startup' -match $DriftSources) 'drift checks on startup'
foreach ($source in 'resume', 'clear', 'compact') {
    Test-Case $false ($source -match $DriftSources) "drift skips $source"
}

"$($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
