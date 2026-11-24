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

    # A subagent's call names its parent's transcript; only the subagent's own sidechain counts.
    foreach ($pair in @(@('mention', 'read'), @('read', 'mention'))) {
        $subagentDir = Join-Path $fixtureDir "$($pair[0])\subagents"
        New-Item -ItemType Directory -Path $subagentDir | Out-Null
        Copy-Item (Join-Path $fixtureDir "$($pair[1]).jsonl") (Join-Path $subagentDir 'agent-sub.jsonl')
    }
    function Invoke-Gate($transcript, $agentId) {
        $request = ConvertTo-Json @{ tool_input = @{ file_path = '/repo/README.md' }; transcript_path = $transcript; agent_id = $agentId } -Compress
        # -join, because a [string] cast of an empty pipeline stays $null.
        return ($request | pwsh -NoProfile -File (Join-Path $TopDir 'claude-code\hooks\prose-gate.ps1')) -join ''
    }
    Test-Case '' (Invoke-Gate $mention 'sub') 'subagent that read english.md under an unread parent is allowed'
    Test-Case $true ((Invoke-Gate (Join-Path $fixtureDir 'read.jsonl') 'sub').Contains('"deny"')) 'subagent that never read english.md under a read parent is denied'

    # A fork inherits the parent's transcript up to its branch point without copying it, and the
    # parent reads english.md at u2.
    $forkParent = Join-Path $fixtureDir 'fork.jsonl'
    Set-Content -LiteralPath $forkParent -Value @'
{"uuid":"u1","type":"user","message":{"content":"hi"}}
{"uuid":"u2","type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/english.md"}}]}}
{"uuid":"u3","type":"user","message":{"content":"bye"}}
'@
    New-Item -ItemType Directory -Path (Join-Path $fixtureDir 'fork\subagents') | Out-Null
    foreach ($branch in 'u1', 'u2') {
        Set-Content -LiteralPath (Join-Path $fixtureDir "fork\subagents\agent-$branch.jsonl") -Value @(
            "{`"type`":`"fork-context-ref`",`"parentLastUuid`":`"$branch`"}"
            '{"type":"user","message":{"content":"probe"}}'
        )
    }
    Test-Case $true (Test-EnglishMdInContext $forkParent $sentinel 'u2') 'fork branched after the parent read english.md'
    Test-Case $false (Test-EnglishMdInContext $forkParent $sentinel 'u1') 'fork branched before the parent read english.md'
}
finally {
    Remove-Item -Recurse -Force $fixtureDir
}

"$($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
