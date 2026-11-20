# Reports
A report is the file a skill run leaves in `.agent/reports/`, for two readers: the user reviewing a run they did not watch, and a later session grepping for what an earlier run covered or decided. A deliverable the user asks for by hand, such as a PR draft, an image, or a one-off write-up, is not a report and goes to `outbox/`.

## Creating
Start the report before the run's first edit, so its commit names the tree the run inherited:

```
bash practices/reports/new-report.sh --repo <repo> --skill <skill> [--subject <slug>]
```

The script claims the next name, `YYYYMMDD<seq>-<skill>[-<subject>].md` such as `20261120a-consult-agenda-ids.md`, writes the front matter fields it can supply, and prints the path. `<seq>` is the day's run sequence across every skill, so the directory lists in run order. Never pick the name by hand, because two sessions would then claim the same sequence letter. Pass `--subject` only where the run has a natural subject, a few lowercase hyphenated words: a `/consult` subject, or the component a scoped `/refine` covers. A run over a diff or the whole agenda has none.

Then `Read` the file and complete it in one `Write`.

## Front matter
```
---
skill: refine
date: 2026-11-20
branch: main
commit: 8464ba4-dirty
subject: hud-blending
scope: [src/hud/, src/pause.rs]
mode: autonomous
model: claude-opus-5-5
effort: high
opened: [14, 15]
closed: [9]
---
```

The script writes `skill`, `date`, `branch`, `commit` (suffixed `-dirty` when tracked files had uncommitted changes), and `subject`. The run adds the rest:
- `scope` - what the run covered, as paths or a diff spec such as `git diff main`, where the skill has a scope
- `mode` - `guided` or `autonomous`, where the skill has modes
- `model` and `effort` - the model ID and effort level the run used
- `opened` - agenda IDs of the items the run added
- `closed` - agenda IDs of the items the run resolved or dropped

Keep `opened` and `closed` even when empty, as `[]`. A field that does not apply is left out. Every value stays on one line, so `grep -l '^branch: main' .agent/reports/*.md` and similar greps work.

## Body
The title is `# <Skill> <subject, scope, or branch>`. The skill gives the sections. An open item opens with its agenda ID, as in `1. **#14 Drop the legacy parser**`, and carries no status marker: the agenda is the only tracker of what is still open, so a report never records an item's later fate.

## Archive
A report is a record of its run and never changes once the run ends, except for its move to `reports/_archive/`. It moves there once every ID in its `opened` appears in `.agent/doc/agenda-log.md`. A run that opened nothing moves its own report at its close. Otherwise the session whose agenda removal logs the last open ID moves the report it links. The archive is flat and kept forever.

Reports written before this format, under `outbox/`, move to `reports/_archive/` with their contents unchanged, as `/tidy` describes.
