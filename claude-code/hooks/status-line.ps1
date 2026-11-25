# Status line (Windows): the recommended commit title that practices/commit-title.sh keeps for the
# session's directory, marked when the working state changed since it was written. Prints nothing
# outside a git repo, when no title is stored, or when the title is stale on a clean tree, since
# that title was most likely for work already committed. commit-title.sh runs under the Git Bash on
# PATH.
#
# Every change here is mirrored in status-line.sh, and test/status-line-cases.tsv must pass on both.
param(
    # Load the policy without reading stdin, which is how the tests drive it.
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'

$CommitTitle = Join-Path $PSScriptRoot '..\practices\commit-title.sh'

# Returns the status line for one line of commit-title.sh output and the tree state (clean or
# dirty), or nothing.
function Get-StatusLine($check, $tree) {
    if ($check -match '^fresh (.*)$') { return "commit: $($Matches[1])" }
    if ($check -match '^stale (.*)$' -and $tree -ne 'clean') { return "commit (stale): $($Matches[1])" }
}

# Returns clean when git sees no staged, unstaged, or untracked change, else dirty.
function Get-TreeState($dir) {
    $porcelain = git -C $dir status --porcelain
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($porcelain) { return 'dirty' }
    return 'clean'
}

function Invoke-StatusLine {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $workspace = $request.PSObject.Properties['workspace']
    $dir = if ($workspace -and $workspace.Value.PSObject.Properties['current_dir']) { [string]$workspace.Value.current_dir } else { '' }
    if (-not $dir) { return }

    # Windows PowerShell turns redirected native stderr into a terminating error under Stop.
    $top = $null
    try { $top = git -C $dir rev-parse --show-toplevel 2>$null } catch {}
    if (-not $top) { return }

    $check = bash $CommitTitle --repo $dir
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    # Only a stale title reads the tree state, so the common case skips a git call.
    $tree = if ($check -match '^stale ') { Get-TreeState $dir } else { 'dirty' }
    $line = Get-StatusLine $check $tree
    if ($line) { [Console]::Out.Write($line) }
}

if (-not $LibraryOnly) {
    Invoke-StatusLine
}
