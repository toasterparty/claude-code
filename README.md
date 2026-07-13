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

## Other Documentation

- [Reusable Prompts](./doc/prompts.md)
