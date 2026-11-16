# claude-code

Source of truth for a personal Claude Code configuration: an online backup that also deploys to every machine the user works on.

**Number-one pitfall:** a prompt about "my CLAUDE.md", "my settings", or "my language rules" means the tracked copy under `claude-code/` in this repo, never the live file in `~/.claude/` (or `$CLAUDE_DIR`). The live files are regenerated from this repo on every install.

Layout:
- `claude-code/` - the deployed payload, mirrored into the Claude Code home directory: `CLAUDE.md`, `settings.json`, `languages/`, `practices/`, `hooks/`, `output-styles/`, `skills/`
- `doc/` - human-facing docs, published with `README.md` via GitHub Pages
- `test/` - not deployed; each hook has a `.sh`/`.ps1` runner pair asserting both twins against one shared `*-cases.tsv`. Run both runners after any edit to a hook - the two twins must decide identically
- `install.sh` / `install.ps1` - idempotent deploy scripts; each replaces every top-level entry of `claude-code/` wholesale and key-merges `settings.json` (tracked keys win)

The install scripts download the repo archive at the commit `main` points at and stamp it into `<claude home>/.deployed-commit`, which the session-start hook compares against `main`. An edit here changes nothing live until the user pushes and reruns install.

Update the language file list under `Guidance files` in `claude-code/CLAUDE.md` whenever a file directly under `claude-code/languages/` is added or removed.
