# Makefile scaffold
Start a Makefile with this header, which forces every recipe to run under bash on every OS:
```Makefile
.PHONY: install run start stop logs test format upgrade clean
.DEFAULT_GOAL := run

ifeq ($(OS),Windows_NT)
    # Guard via BASH, not SHELL: make silently falls back to cmd.exe on an empty SHELL.
    BASH_CACHE := build/.bash-path
    BASH := $(file < $(BASH_CACHE))
    space := $() $()
    ifeq ($(wildcard $(subst $(space),\$(space),$(BASH))),)
        BASH := $(shell powershell -NoProfile -ExecutionPolicy Bypass -File tools/find-bash.ps1)
        ifeq ($(BASH),)
            $(error Git bash not found by tools/find-bash.ps1)
        endif
        ifneq ($(wildcard build),)
            $(file > $(BASH_CACHE),$(BASH))
        endif
    endif
    SHELL := $(BASH)
else
    SHELL := bash
endif
.SHELLFLAGS := -euo pipefail -c
```

On Windows the header relies on two helper scripts. Write each verbatim into the project's `tools/`.

`tools/find-bash.ps1` prints the path to Git bash, or nothing if not found. No side effects, so it is safe to run on every make invocation:
```powershell
# Print Git's bash.exe path (never the System32 WSL launcher), or nothing if not
# found. Reads PATH from the registry so a bash installed in another session is
# found without restarting the terminal.

$ErrorActionPreference = "SilentlyContinue"

function Find-Bash {
    $regPath = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
               [Environment]::GetEnvironmentVariable("Path", "User")

    foreach ($dir in ($regPath -split ";" | Where-Object { $_ })) {
        if ($dir -like "*System32*") { continue }
        $candidate = Join-Path $dir "bash.exe"
        if (Test-Path $candidate) { return $candidate }
    }

    # Derive from git.exe: walk up to the Git root and find bin\bash.exe.
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git) {
        $dir = Split-Path $git.Source
        while ($dir -and -not (Test-Path (Join-Path $dir "bin\bash.exe"))) {
            $parent = Split-Path $dir
            $dir = if ($parent -eq $dir) { $null } else { $parent }
        }
        if ($dir) { return (Join-Path $dir "bin\bash.exe") }
    }

    foreach ($p in @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:LocalAppData\Programs\Git\bin\bash.exe"
    )) {
        if ($p -and (Test-Path $p)) { return $p }
    }
}

$bash = Find-Bash
if ($bash) { $bash.Replace('\', '/') }
```

`tools/install-bash.ps1` installs Git and make via winget where missing, then persists bash on PATH. Run once to bootstrap; idempotent. `-Update` upgrades both to latest:
```powershell
# Ensure Git bash and GNU make are available, then put bash on PATH. -Update pulls
# them to latest.
param([switch]$Update)

$ErrorActionPreference = "Stop"

function Install-Tool($id, $probe) {
    if (-not $Update -and (& $probe)) { return }

    # `winget install` updates a package that is already present, and exits
    # non-zero when it is already current; neither is an error here.
    winget install --id $id -e --source winget --disable-interactivity `
        --accept-package-agreements --accept-source-agreements 2>&1 |
        Where-Object { $_ -notmatch "No available upgrade found|No newer package versions are available|Found an existing package already installed" }
    $global:LASTEXITCODE = 0
}

Install-Tool "Git.Git" { [bool](& "$PSScriptRoot\find-bash.ps1") }
Install-Tool "ezwinports.make" { [bool](Get-Command make.exe -ErrorAction SilentlyContinue) }

$bash = & "$PSScriptRoot\find-bash.ps1"

if (-not $bash) {
    throw "Git bash.exe not found after installing Git.Git via winget."
}

$bashDir = Split-Path $bash
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Persist on PATH for future shell instances...
if (($userPath -split ";") -notcontains $bashDir) {
    $userPath = if ($userPath) { "$bashDir;$userPath" } else { $bashDir }
    [Environment]::SetEnvironmentVariable("Path", $userPath, "User")
}

# ...and in this shell now, without a restart, with whatever the installs added.
# Prepended so it wins over the System32 bash.exe that launches WSL.
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$env:Path = (@($bashDir) + ($env:Path, $machinePath, $userPath -split ";") |
    Where-Object { $_ } | Select-Object -Unique) -join ";"
```
