# GNU Make (Makefile)
Before creating a Makefile or changing how it selects its shell, read `languages/make/scaffold.md` in the Claude home directory.

- Keep state-changing recipes idempotent (`install`, `start`, `stop`, `clean`): re-running converges rather than erroring or duplicating. (`run` is a foreground process, not a state to converge on.)
- Keep recipes to a few lines; extract anything more complex into a `tools/*.sh` script.
- Combine recipes that are never used separately.
- Define shared boilerplate once, before the first recipe:
```Makefile
UV_RUN := uv run --locked
```
- Nearly all targets are phony; rarely use file (non-PHONY) targets.
