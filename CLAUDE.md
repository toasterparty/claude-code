# claude-code

Source of truth for a personal Claude Code configuration: an online backup that also deploys to every machine the user works on.

**Number-one pitfall:** a prompt about "my CLAUDE.md", "my settings", or "my language rules" means the tracked copy under `claude-code/` in this repo, never the live file in `~/.claude/` (or `$CLAUDE_DIR`). The live files are regenerated from this repo on every install.

Layout:
- `claude-code/` - the deployed payload, mirrored into the Claude Code home directory: `CLAUDE.md`, `settings.json`, `languages/`, `skills/`
- `doc/` - human-facing docs, published with `README.md` via GitHub Pages
- `install.sh` / `install.ps1` - idempotent deploy scripts; each replaces every top-level entry of `claude-code/` wholesale and key-merges `settings.json` (tracked keys win)

The install scripts download the repo archive from GitHub `main`, so an edit here changes nothing live until the user pushes and reruns install.

Update the README contents list whenever a file under `doc/` or `claude-code/` is added or removed.
