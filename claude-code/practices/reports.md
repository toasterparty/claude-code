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
config: 8bc3aaa
scope: [src/hud/, src/pause.rs]
result: ae17b34c530b39545cd61b5362599b5bacbe12c5
mode: autonomous
model: claude-opus-5-5
opened: [14, 15]
closed: [9]
---
```

The script writes `skill`, `date`, `branch`, `commit` (suffixed `-dirty` when tracked files had uncommitted changes), `subject`, and `config`, the short commit of the deployed Claude configuration, so an outcome can be tied to the rules that produced it. The run adds the rest:
- `scope` - what the run covered, as paths or a diff spec such as `git diff main`, where the skill has a scope
- `result` - where `scope` is a list of paths, the output of `bash practices/reports/scope-hash.sh --repo <repo> <path>...` for those paths, taken after the run's last edit. A later run reruns `bash practices/reports/scope-hash.sh --repo <repo> <path>...` on the report's `scope` paths, and output equal to `result` means the scope is unchanged since that run, which `commit` cannot show: it names the tree the run inherited, before the run's own edits. A report with no `result`, or whose `scope` names a path that no longer exists, counts as changed. A diff-spec scope gets no `result`
- `mode` - the mode or intent the run used, in the skill's own word for it, such as `guided`, `autonomous`, or `orchestrate`, where the skill has modes
- `model` - the exact model ID your environment states, never a guess
- `opened` - agenda IDs of the items the run added
- `closed` - agenda IDs of the items the run resolved or dropped

Keep `opened` and `closed` even when empty, as `[]`. A field that does not apply is left out. Every value stays on one line, so `grep -l '^branch: main' .agent/reports/*.md` and similar greps work.

## Body
The title is `# <Skill> <subject, scope, or branch>`. The skill gives the sections. An open item opens with its agenda ID, as in `1. **#14 Drop the legacy parser**`, and carries no status marker: the agenda is the only tracker of what is still open, so a report never records an item's later fate.

## Closing a run
Close a run in this order, because the report carries the IDs of the items the run opened. The skill names which items it opens and removes, and which sections its body has.
1. Add the agenda items the run leaves open, one per point, grouping points that would be resolved together, each linking this report and tagged as `practices/agenda.md` directs. Take every ID from `next-id.sh` first, under that file's `IDs`.
2. Remove the items the run settled with `resolve.sh`, as `practices/agenda.md` `Updating` describes.
3. Complete the report in one `Write`, after the run's last edit: `opened` lists the IDs step 1 added, `closed` every ID the run removed, and each open item in the body opens with its ID.
4. Where `opened` is empty, move the report to `reports/_archive/`.

A subagent takes its IDs in step 1 but leaves the agenda edits of steps 1 and 2 to its parent session, as `practices/agenda.md` describes, and still runs steps 3 and 4.

## Archive
A report is a record of its run and never changes once the run ends, except for its move to `reports/_archive/`. It moves there once every ID in its `opened` appears in `.agent/doc/agenda-log.md`. A run that opened nothing moves its own report at its close. Otherwise `resolve.sh`, which every agenda removal runs, moves the report once the removal logs its last open ID, as `practices/agenda.md` describes. The archive is flat and kept forever.

Reports written before this format, under `outbox/`, move to `reports/_archive/` with their contents unchanged, as `/tidy` describes.
