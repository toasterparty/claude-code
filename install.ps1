# Install/upgrade Claude Code and deploy this repo's config into ~/.claude.
#Requires -Version 5
$ErrorActionPreference = 'Stop'

$RepoArchive = 'https://github.com/toasterparty/claude-code/archive/refs/heads/main.zip'
$ClaudeDir = if ($env:CLAUDE_DIR) { $env:CLAUDE_DIR } else { Join-Path $HOME '.claude' }
$script:TempDir = $null

function Write-Step($msg) { Write-Host "==> $msg" }

function Install-ClaudeCode {
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Step 'Updating Claude Code'
        claude update
    }
    else {
        Write-Step 'Installing Claude Code'
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    }
}

# Download the repo and return the config directory within it.
function Resolve-Source {
    Write-Step "Downloading config from $RepoArchive"
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    $zip = Join-Path $script:TempDir 'repo.zip'
    Invoke-WebRequest -Uri $RepoArchive -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $script:TempDir -Force
    return (Join-Path $script:TempDir 'claude-code-main\claude-code')
}

# Recursively merge $overlay into $base in place (overlay wins on conflicts).
function Merge-Json($base, $overlay) {
    foreach ($prop in $overlay.PSObject.Properties) {
        $existing = $base.PSObject.Properties[$prop.Name]
        if ($existing -and ($existing.Value -is [PSCustomObject]) -and ($prop.Value -is [PSCustomObject])) {
            Merge-Json $existing.Value $prop.Value
        }
        elseif ($existing) { $existing.Value = $prop.Value }
        else { $base | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value }
    }
}

# Enforce the keys from the tracked settings.json onto the user's existing file,
# preserving any keys the user set that we don't specify.
function Merge-Settings($tracked, $target) {
    if (-not (Test-Path $tracked)) { return }
    $trackedObj = Get-Content -Raw $tracked | ConvertFrom-Json
    $baseObj = if (Test-Path $target) { Get-Content -Raw $target | ConvertFrom-Json } else { $null }
    if (-not $baseObj) { $baseObj = [PSCustomObject]@{} }
    Merge-Json $baseObj $trackedObj
    [System.IO.File]::WriteAllText($target, ($baseObj | ConvertTo-Json -Depth 20))
}

function Sync-Config($src) {
    Write-Step "Deploying config into $ClaudeDir"
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    $srcFull = (Resolve-Path $src).Path
    Get-ChildItem -Path $srcFull -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($srcFull.Length).TrimStart('\', '/')
        if ($rel -eq 'settings.json') { return }
        $dest = Join-Path $ClaudeDir $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -Path $_.FullName -Destination $dest -Force
    }
    Merge-Settings (Join-Path $srcFull 'settings.json') (Join-Path $ClaudeDir 'settings.json')
}

try {
    Install-ClaudeCode
    Sync-Config (Resolve-Source)
    Write-Step "Done. Config deployed to $ClaudeDir"
}
finally {
    if ($script:TempDir -and (Test-Path $script:TempDir)) { Remove-Item -Recurse -Force $script:TempDir }
}
