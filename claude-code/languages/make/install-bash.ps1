$ErrorActionPreference = "Stop"

function Install-Latest($id) {
    winget list --id $id -e --source winget *> $null
    $verb = if ($LASTEXITCODE -eq 0) { "upgrade" } else { "install" }
    winget $verb --id $id -e --source winget --disable-interactivity `
        --accept-package-agreements --accept-source-agreements 2>&1 |
        Where-Object { $_ -notmatch "No available upgrade found|No newer package versions are available" }
    # "Already current" exits non-zero; not an error.
    $global:LASTEXITCODE = 0
}

Install-Latest "Git.Git"
Install-Latest "ezwinports.make"

$bash = & "$PSScriptRoot\find-bash.ps1"

if (-not $bash -or -not (Test-Path $bash)) {
    throw "Could not locate Git bash.exe. Ensure Git for Windows installed correctly."
}

$bashDir = Split-Path $bash

# Persist on PATH for future terminals.
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $bashDir) {
    $newPath = if ($userPath) { "$bashDir;$userPath" } else { $bashDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}

# And in this shell now, without a restart.
if (($env:Path -split ";") -notcontains $bashDir) {
    $env:Path = "$bashDir;$env:Path"
}
