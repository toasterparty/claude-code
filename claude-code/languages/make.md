# GNU Make (Makefile)

A top-level Makefile is the application-developer interface for a project: it normalizes details that vary project-to-project (language, framework, buildsystem) behind a few memorable, hand-typed targets. Treat it as living introductory documentation - keep it simple and free of clutter.

## Purpose & scope
- Expose intent (`install`, `run`, `test`, ...), not implementation; hide the underlying commands behind targets.
- CI/CD invokes make targets, never the recipe commands directly - one source of truth for how the project builds, runs, and tests.
- This is a task runner, not a build graph: `make` runs the recipe every time and does not skip work when nothing changed. Delegate real incremental builds to the underlying buildsystem.

## Standard targets
Reuse these names across projects so the interface is predictable:
```sh
make install   # one-time project setup
make run       # run in the foreground (this shell)
make start     # start in the background (restart if already running)
make stop      # stop the backgrounded application, if running
make logs      # tail the backgrounded application's log, if running
make test      # non-mutating gate: format check, static analysis, unit + integration tests
make format    # apply formatting fixes in place (dev convenience; CI runs test, never this)
make upgrade   # bump all dependencies to latest
make clean     # erase all generated files
```

## Recipes
- Keep state-changing recipes idempotent (`install`, `start`, `stop`, `clean`): re-running converges rather than erroring or duplicating. (`run` is a foreground process, not a state to converge on.)
- Keep recipes to a few lines; extract anything more complex into a `tools/*.sh` script.
- Combine recipes that are never used separately.
- Define shared boilerplate once, before the first recipe:
```Makefile
UV_RUN := uv run --locked
```
- Nearly all targets are phony; rarely use file (non-PHONY) targets.

## Multi-OS scaffolding
Start a cross-platform Makefile by forcing every recipe to run under bash:
```Makefile
.PHONY: install run start stop logs test format upgrade clean
.DEFAULT_GOAL := run

ifeq ($(OS),Windows_NT)
    # Guard via BASH, not SHELL: make silently falls back to cmd.exe on an empty SHELL.
    BASH := $(shell powershell -NoProfile -File tools/find-bash.ps1)
    ifeq ($(BASH),)
        $(error Could not locate Git bash - run tools/install-bash.ps1 (open a new terminal if you just installed it))
    endif
    SHELL := $(BASH)
else
    SHELL := bash
endif
.SHELLFLAGS := -euo pipefail -c
```

On Windows this relies on two helper scripts under `tools/`.

`find-bash.ps1` prints the path to Git bash (never the System32 WSL launcher), or nothing if not found. It reads PATH from the registry so a bash installed in another session is found without restarting the terminal, and emits forward slashes so the path is safe to assign to `SHELL`. No side effects, so it is safe to run on every make invocation:
```ps1
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

`install-bash.ps1` installs Git and make via winget, then persists bash on PATH. Run it once to bootstrap; it is idempotent (upgrades whatever is already present):
```ps1
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
```
