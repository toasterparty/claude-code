# Asserts status-line.ps1 against test/status-line-cases.tsv and the fixtures below.
# Run run-status-line-tests.sh for the .sh twin.
$ErrorActionPreference = 'Stop'

$TopDir = Split-Path -Parent $PSScriptRoot
$Hook = Join-Path $TopDir 'claude-code\hooks\status-line.ps1'
$CommitTitle = Join-Path $TopDir 'claude-code\practices\commit-title.sh'
. $Hook -LibraryOnly

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

foreach ($line in Get-Content (Join-Path $PSScriptRoot 'status-line-cases.tsv')) {
    if (-not $line.Trim() -or $line.StartsWith('#')) { continue }

    $fields = $line -split "`t", 3
    $checkLine = ConvertFrom-Dash $fields[0]
    $tree = $fields[1]
    $expected = ConvertFrom-Dash $fields[2]
    Test-Case $expected (Get-StatusLine $checkLine $tree) "commit-title.sh printed '$($fields[0])' on a $tree tree"
}

# The status line end to end: Claude Code's status JSON on stdin, the line or nothing on stdout.
# The ceiling keeps the fixture's non-repo directory from finding a repo above the temp dir.
$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$repo = Join-Path $fixtureDir 'repo'
$savedCeiling = $env:GIT_CEILING_DIRECTORIES
New-Item -ItemType Directory -Path (Join-Path $repo 'sub'), (Join-Path $fixtureDir 'plain') | Out-Null
try {
    $env:GIT_CEILING_DIRECTORIES = $fixtureDir
    git init -q $repo
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'first'

    function Test-Line($expected, $request, $label) {
        $actual = ($request | pwsh -NoProfile -File $Hook) -join ''
        if ($LASTEXITCODE -ne 0) { $actual = "exit $LASTEXITCODE" }
        Test-Case $expected $actual "end to end: $label"
    }

    function New-Request($dir) {
        @{ cwd = $dir; workspace = @{ current_dir = $dir; project_dir = $dir } } | ConvertTo-Json -Compress
    }

    Test-Line '' (New-Request $repo) 'a repo with no stored title shows nothing'
    bash $CommitTitle --repo $repo --title 'Add a.txt'
    Test-Line 'commit: Add a.txt' (New-Request $repo) 'a title written for this state shows'
    Test-Line 'commit: Add a.txt' (New-Request (Join-Path $repo 'sub')) 'a subdirectory shows the repo root title'
    Add-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'edit'
    Test-Line 'commit (stale): Add a.txt' (New-Request $repo) 'an edit since the title was written marks it stale'
    # Deleting the repo's only file stands in for a commit, which would need a git write.
    Remove-Item -LiteralPath (Join-Path $repo 'a.txt')
    Test-Line '' (New-Request $repo) 'a stale title on a clean tree shows nothing'
    Test-Line '' (New-Request (Join-Path $fixtureDir 'plain')) 'a directory outside any repo shows nothing'
    Test-Line '' '{"model":{"display_name":"Opus"}}' 'a request without a workspace shows nothing'
}
finally {
    $env:GIT_CEILING_DIRECTORIES = $savedCeiling
    Remove-Item -Recurse -Force $fixtureDir
}

"$($total - $failed)/$total passed"
if ($failed -gt 0) { exit 1 }
