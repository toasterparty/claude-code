# GNU Make (Makefile)
Before creating a Makefile or changing how it selects its shell, read `languages/make/scaffold.md`.

- Keep state-changing recipes (`install`, `start`, `stop`, `clean`) idempotent.
- Keep recipes to a few lines; extract anything more complex into a `tools/*.sh` script.
- Combine recipes that are never used separately.
- Define shared boilerplate once, before the first recipe:
```Makefile
UV_RUN := uv run --locked
```
- Make is a task runner, not a build graph: targets are phony, and incremental builds belong to the underlying buildsystem.
