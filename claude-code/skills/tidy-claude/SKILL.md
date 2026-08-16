---
name: tidy-claude
description: Tidy the current repository's .claude/ directory into the standard inbox/outbox/scripts/doc layout - scaffold the dirs, migrate legacy ones, archive finished work, purge regenerable junk, repair the indexes.
disable-model-invocation: true
---

Bring `<repo>/.claude/` in the current repository into the layout the user CLAUDE.md defines. Survey the whole directory first, then run the passes below in order.

## Scope
Touch only the four layout dirs (`inbox/`, `outbox/`, `scripts/`, `doc/`) and the legacy dirs they replace (`plans/`, `reference/`, `agent/`). Leave every Claude-Code-native entry alone: `skills/`, `agents/`, `commands/`, `hooks/`, `settings*.json`, lock files. Never edit a file under `inbox/`; migrating a whole file out of a legacy dir is the one move allowed against user content.

## 1. Create the layout
Ensure all four layout dirs exist, creating whichever are missing. Leave a dir in place even if nothing lands in it - an empty `inbox/` is how the user learns where to drop the next plan. Subdirectories, `_archive/` included, are still created on first use.

## 2. Migrate legacy layouts
- `reference/*` -> `inbox/`
- `plans/*` -> `inbox/`, and its `archive/` or `_archive/` subdirs -> `inbox/_archive/`
- `agent/` scripts -> `scripts/` if worth reusing, otherwise delete
- `agent/` notes that still teach something -> `doc/`
- agent-authored reports in any legacy dir -> `outbox/_archive/`

## 3. Purge and archive
Delete regenerable artifacts outright: caches, `__pycache__`, virtualenvs, build outputs, logs, re-downloadable binaries. Archiving them just relocates wasted space.

Everything else keeps its bytes. Non-regenerable data (captured baselines, recorded measurements, one-off datasets) is never deleted regardless of size, and files tied to a resolved issue move into an `_archive/` inside the directory they already live in.

## 4. Generalize
Rewrite surviving scripts and docs so an agent on a different task can use them: strip one-off paths, task-specific names, and hardcoded inputs; take arguments instead.

## 5. Index
Create or repair `index.md` in `scripts/` and `doc/` - one line per entry, the filename then when a future agent would need it. Drop lines whose file no longer exists.

## 6. Ignore rules
Ensure `.claude/.gitignore` exists and starts with `*`, so the directory is fully untracked, and drop any obsolete `!CLAUDE.md` exception. Preserve un-ignores for Claude-Code-native entries a team repo tracks deliberately; re-including a directory takes two lines, since `*` matches at every level:
```
*
!settings.json
!skills/
!skills/**
```
Files already committed stay tracked until the user untracks them. Never touch the git index.

## 7. Project memory
Update `.claude/CLAUDE.md` to match the tidied directory, and cut its token bloat: stale paths, rules the user CLAUDE.md already carries, prose that restates itself.

## Report
List the moves, the deletions, and the files you generalized. Flag anything left in place because its fate was unclear.
