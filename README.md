# Toaster's Claude Code Setup

If I don't have agentic LLM setup in this particular way, I end up spending more energy fixing the output than I save on development effort. This setup is built upon a foundational preference for executing a few ambitious/expensive prompts a week instead of the more common "conversational" approach to agentic AI. That shit frustrates me.

This repository has two purposes: (1) Online backup of my agentic LLM configuration. (2) Streamline deployment of updates to this configuration across my many installation instances.

The scripts provided by this repository handle the following (idempotently):
- Installation of Claude Code
- Upgrading of Claude Code
- Adding of Claude Code to PATH
- Updating the contents of the user-space claude directory (default: `~/.claude/`) with the files in `claude-code/`

> Note: Install scripts overwrite `CLAUDE.md` and a few user settings.

## Usage

### Linux/MacOS (Bash)

```sh
curl -fsSL https://claude.toasterparty.net/install.sh | bash
```

### Windows (PowerShell)

```sh
irm https://claude.toasterparty.net/install.ps1 | iex
```

### Custom Claude Code Home Directory

Set `CLAUDE_DIR` to deploy into a directory other than the default `~/.claude/`.

Linux/MacOS:

```sh
curl -fsSL https://claude.toasterparty.net/install.sh | CLAUDE_DIR="$HOME/.claude-work" bash
```

Windows:

```sh
$env:CLAUDE_DIR = "$HOME\.claude-work"; irm https://claude.toasterparty.net/install.ps1 | iex
$env:CLAUDE_DIR = "$HOME\.claude-personal"; irm https://claude.toasterparty.net/install.ps1 | iex
```

## Contents

Documentation:

- [API Usage Summary](./doc/api-usage.md)
- [Reusable Prompts](./doc/prompts.md)

Deployed configuration (`claude-code/`):

- [CLAUDE.md](./claude-code/CLAUDE.md) - rules, strategy, and values loaded into every session
- [settings.json](./claude-code/settings.json)
- [hooks/permission-gate.ps1](./claude-code/hooks/permission-gate.ps1) - Windows PreToolUse gate: auto-approves tool calls that policy allows, so nothing waits on a prompt
- [hooks/permission-gate.sh](./claude-code/hooks/permission-gate.sh) - the same gate for Linux/MacOS
- [languages/bash.md](./claude-code/languages/bash.md)
- [languages/c.md](./claude-code/languages/c.md)
- [languages/english.md](./claude-code/languages/english.md)
- [languages/make.md](./claude-code/languages/make.md)
- [languages/make/find-bash.ps1](./claude-code/languages/make/find-bash.ps1) - helper copied into projects that use the cross-platform Makefile scaffolding
- [languages/make/install-bash.ps1](./claude-code/languages/make/install-bash.ps1) - one-time Windows bootstrap for the same scaffolding
- [languages/python.md](./claude-code/languages/python.md)
- [skills/tidy-claude](./claude-code/skills/tidy-claude/SKILL.md)

Tests (`test/`), not deployed:

- [gate-cases.tsv](./test/gate-cases.tsv) - expected permission-gate decision per command, shared by both runners
- [run-gate-tests.sh](./test/run-gate-tests.sh) - asserts `hooks/permission-gate.sh` against those cases
- [run-gate-tests.ps1](./test/run-gate-tests.ps1) - the same for `hooks/permission-gate.ps1`
