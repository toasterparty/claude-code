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

On Windows this relies on two helper scripts. Copy them verbatim from the `make/` directory beside this file into the project's `tools/`:
- `find-bash.ps1` prints the path to Git bash (never the System32 WSL launcher), or nothing if not found. No side effects, so it is safe to run on every make invocation.
- `install-bash.ps1` installs Git and make via winget, then persists bash on PATH. Run once to bootstrap; idempotent.
