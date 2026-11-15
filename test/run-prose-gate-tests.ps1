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

    $englishText = Get-Content -LiteralPath $EnglishPath -Raw
    $sentinel = Get-EnglishSentinel $englishText

    # A shell read leaves the file's text in a tool_result, never a file_path.
    function Write-ToolResultFixture($name, $text) {
        $line = ConvertTo-Json @{ type = 'user'; message = @{ content = @(@{ type = 'tool_result'; content = $text }) } } -Depth 5 -Compress
        Set-Content -LiteralPath (Join-Path $fixtureDir $name) -Value $line
    }
    Write-ToolResultFixture 'cat.jsonl' $englishText
    Write-ToolResultFixture 'denial.jsonl' "PreToolUse:Write hook error: $(Get-DenialReason $englishText)"

    $mention = Join-Path $fixtureDir 'mention.jsonl'
    Test-Case $true ($sentinel.Length -ge 40) 'sentinel is a distinctive line of english.md'
    Test-Case $true (Test-EnglishMdInContext (Join-Path $fixtureDir 'read.jsonl') $sentinel) 'transcript holding a read of english.md'
    Test-Case $true (Test-EnglishMdInContext (Join-Path $fixtureDir 'cat.jsonl') $sentinel) 'transcript holding english.md read through a shell'
    Test-Case $true (Test-EnglishMdInContext (Join-Path $fixtureDir 'denial.jsonl') $sentinel) 'transcript holding an earlier denial'
    Test-Case $false (Test-EnglishMdInContext $mention $sentinel) 'transcript that only names english.md'
    Test-Case $false (Test-EnglishMdInContext $mention '') 'missing english.md leaves no empty sentinel matching everything'
    Test-Case $true (Test-EnglishMdInContext (Join-Path $fixtureDir 'absent.jsonl') $sentinel) 'unreadable transcript fails open'
    Test-Case $ReasonUnread (Get-DenialReason '') 'missing english.md falls back to asking for a read'

    $request = ConvertTo-Json @{ tool_input = @{ file_path = '/repo/README.md' }; transcript_path = $mention } -Compress
    $denial = ($request | pwsh -NoProfile -File (Join-Path $TopDir 'claude-code\hooks\prose-gate.ps1') | ConvertFrom-Json).hookSpecificOutput.permissionDecisionReason
    Test-Case $true ($denial.Contains($sentinel)) 'hook denial is valid JSON carrying english.md'
}
finally {
    Remove-Item -Recurse -Force $fixtureDir
}

"$($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
