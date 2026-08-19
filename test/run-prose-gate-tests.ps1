# Asserts prose-gate.ps1 against test/prose-gate-cases.tsv and the transcript fixtures below.
# Run run-prose-gate-tests.sh for the .sh twin.
$ErrorActionPreference = 'Stop'

$TopDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $TopDir 'claude-code\hooks\prose-gate.ps1') -LibraryOnly

$total = 0
$failed = 0

function Test-Case($expected, $actual, $label) {
    $script:total++
    if ($actual -ne $expected) {
        $script:failed++
        "FAIL expected=$expected actual=$actual : $label"
    }
}

foreach ($line in Get-Content (Join-Path $PSScriptRoot 'prose-gate-cases.tsv')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }

    $fields = $line -split "`t", 3
    $expected = $fields[0].Trim()
    $inContext = [int]$fields[1]
    $filePath = if ($fields.Count -gt 2) { $fields[2] } else { '' }

    $actual = (Get-ProseGateDecision $filePath ($inContext -eq 1)).decision
    Test-Case $expected $actual "in_context=$inContext $(if ($filePath) { $filePath } else { '<no file_path>' })"
}

$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $fixtureDir | Out-Null
try {
    Set-Content -LiteralPath (Join-Path $fixtureDir 'read.jsonl') -Value @'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"C:\\Users\\x\\.claude\\languages\\english.md"}}]}}
'@

    # The name appears in prose and as a search target, neither of which puts the content in context.
    Set-Content -LiteralPath (Join-Path $fixtureDir 'mention.jsonl') -Value @'
{"type":"user","message":{"content":"did you read english.md for the report you made?"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/repo/src/main.c"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Grep","input":{"path":"/repo/languages","pattern":"english.md"}}]}}
'@

    Test-Case $true (Test-EnglishMdInContext (Join-Path $fixtureDir 'read.jsonl')) 'transcript holding a read of english.md'
    Test-Case $false (Test-EnglishMdInContext (Join-Path $fixtureDir 'mention.jsonl')) 'transcript that only names english.md'
    Test-Case $true (Test-EnglishMdInContext (Join-Path $fixtureDir 'absent.jsonl')) 'unreadable transcript fails open'
}
finally {
    Remove-Item -Recurse -Force $fixtureDir
}

"$($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
