# SessionStart hook (Windows): title the session with its directory name, load the project memory in <repo>/.agent/AGENTS.md, which Claude
# Code itself loads only once a file under .agent/ is read, and warn the user when the deployed
# config lags main. Install stamps the deployed commit beside hooks/. The root AGENTS.md loads
# natively through pluginConfigs in settings.json, so printing it here would load it twice.
#
# Every change here is mirrored in session-start.sh, and test/session-start-cases.tsv must pass on both.
param(
    # Load the policy without reading stdin, which is how the tests drive it.
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'

$DeployedCommitFile = Join-Path $PSScriptRoot '..\.deployed-commit'
$LatestCommitUrl = 'https://api.github.com/repos/toasterparty/claude-code/commits/main'
$FetchTimeoutS = 3
$ShortShaLen = 7

# A resumed session already holds the memory it loaded at its start.
$MemorySources = '^(startup|clear|compact)$'
$DriftSources = '^startup$'

# Claude Code applies a hook's sessionTitle only on these sources.
$TitleSources = '^(startup|resume|fork)$'

# Returns the working directory's name as the session title, or nothing when the session already
# has a custom title (a --name or /rename the user chose) or the directory has no name.
function Get-SessionTitle($cwd, $existingTitle) {
    if ($existingTitle) { return }
    ($cwd -replace '\\', '/').TrimEnd('/').Split('/')[-1]
}

# Returns the project memory path for the session's working directory, or nothing.
function Find-ProjectMemory($cwd) {
    $top = $null
    try { $top = git -C $cwd rev-parse --show-toplevel 2>$null } catch {}
    if (-not $top) { $top = $cwd }
    $path = Join-Path $top '.agent/AGENTS.md'
    if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
}

# Returns the drift warning, or nothing when either commit is unknown or they match.
function Get-DriftMessage($deployed, $latest) {
    if (-not $deployed -or -not $latest -or $deployed -eq $latest) { return }
    $short = { param($sha) $sha.Substring(0, [Math]::Min($ShortShaLen, $sha.Length)) }
    'claude-code config deployed from {0}, main is at {1}' -f (& $short $deployed), (& $short $latest)
}

# Returns the commit main points at, or nothing when offline.
function Get-LatestCommit {
    try { return [string](Invoke-RestMethod -Uri $LatestCommitUrl -TimeoutSec $FetchTimeoutS -UseBasicParsing).sha } catch {}
}

function Invoke-SessionStart {
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $source = if ($request.PSObject.Properties['source']) { [string]$request.source } else { '' }
    $cwd = if ($request.PSObject.Properties['cwd']) { [string]$request.cwd } else { '' }

    $specific = @{ hookEventName = 'SessionStart' }
    if ($source -match $MemorySources -and $cwd) {
        $memoryPath = Find-ProjectMemory $cwd
        if ($memoryPath) {
            $content = (Get-Content -Raw -LiteralPath $memoryPath).TrimEnd()
            $specific.additionalContext = "Contents of $memoryPath (project memory):`n`n$content"
        }
    }

    if ($source -match $TitleSources) {
        $existingTitle = if ($request.PSObject.Properties['session_title']) { [string]$request.session_title } else { '' }
        $title = Get-SessionTitle $cwd $existingTitle
        if ($title) { $specific.sessionTitle = $title }
    }

    $payload = @{}
    if ($specific.Count -gt 1) { $payload.hookSpecificOutput = $specific }

    if ($source -match $DriftSources -and (Test-Path -LiteralPath $DeployedCommitFile)) {
        $deployed = (Get-Content -Raw -LiteralPath $DeployedCommitFile).Trim()
        $message = Get-DriftMessage $deployed (Get-LatestCommit)
        if ($message) { $payload.systemMessage = $message }
    }

    if ($payload.Count -eq 0) { return }
    [Console]::Out.Write((ConvertTo-Json $payload -Depth 5 -Compress))
}

if (-not $LibraryOnly) {
    Invoke-SessionStart
}
