---
name: tidy
description: Tidy the current repository's .agent/ directory into the standard inbox/outbox/reports/scripts/doc layout - scaffold the dirs, migrate legacy ones including the old .claude/ layout and CLAUDE.md project memory, archive finished work, drop agenda items already addressed, add agenda items for unaddressed inbox assets, purge regenerable junk, repair the indexes.
disable-model-invocation: true
---

Bring `<repo>/.agent/` into the layout `practices/agent-dir.md` defines, running the passes below in order.

Survey with one recursive listing carrying sizes and dates, and open a file only when its name, size, and location leave its fate open. Batch moves and deletes into as few shell calls as possible rather than one tool call per file.

## Scope
Touch only the five layout dirs and the `git/` scratch dir under `.agent/`, the agenda, the project instruction files, and the legacy locations step 2 names. Never edit a file under `inbox/`.

## 1. Create the layout
Run `bash practices/agent-dir/ensure-layout.sh --repo <repo>`. It creates whichever of `.agent/`, its `.gitignore`, and the five layout dirs (`inbox/`, `outbox/`, `reports/`, `scripts/`, `doc/`) are missing. Never create them with your own `mkdir`: the deny rule that keeps agents out of `inbox/` also blocks any shell command that names `inbox/` as its target, while the script's `mkdir` passes. Keep the dirs even when empty. Subdirectories, `_archive/` and `scripts/data/` included, appear only on first use.

## 2. Migrate legacy layouts
Where the survey finds a legacy location, read `migrate.md` beside this file and migrate as it describes. The legacy locations are `<repo>/.claude/{inbox,outbox,scripts,doc}/`, `plans/`, `reference/`, `agent/`, `scripts/data/tidy-claude/`, a `CLAUDE.md` at the repo root, in `.agent/`, or in `.claude/`, and skill reports under `outbox/` written before `practices/reports.md`. Otherwise skip this step.

## 3. Resolve ambiguity
A file is archived once its work is finished. Ambiguous means neither the file, the repo, nor git history settles that: a plan with unchecked boxes, a report on an unmerged branch, a script whose target still exists.

Collect these during the survey, agenda items of unproven status and inbox assets of unclear status (step 4a) among them, and ask them in one AskUserQuestion batch before the first destructive move, one question per file or related group, each option stating the action it triggers. Whatever the user leaves unresolved stays where it is. Never archive or delete on a guess.

## 4. Purge and archive
Delete regenerable artifacts outright: caches, `__pycache__`, virtualenvs, build outputs, logs, re-downloadable binaries, and every clone under `git/` except the persistent ones `practices/scratch-clones.md` describes. `scripts/data/` collects them fastest.

Everything else keeps its bytes. Never delete non-regenerable data (captured baselines, recorded measurements, one-off datasets), whatever its size. Files tied to a resolved issue move into an `_archive/` inside their current directory. A report in `reports/` whose `opened` IDs all appear in the agenda log moves to `reports/_archive/`.

## 4a. Reconcile the agenda
Read `practices/agenda.md` first. Then check the agenda both ways against `inbox/`, `outbox/`, `reports/`, `doc/`, the repo, and git history: reconcile every item as its `Reconciling` section describes, and add items for the assets below. An unclear item goes to step 3, and is removed on the user's confirmation.

Bring every item to the agenda's item format. Give each item without an ID a new one, taking them all from one `next-id.sh --count <n>` call. Turn a dependency or user task stated in prose into its tag, such as "after the redesign" into `blocked by` the redesign's ID, or "have the user confirm in game" into `User Task`. Cut an item that runs past one line to a headline, moving its context into sub-bullets, or into the linked doc where it is longer than a few short lines.

Add an item for each asset that shows open work and has none: an `inbox/` plan or design doc nobody executed, raw data nobody analyzed, a report with an `opened` ID missing from both the agenda and its log, a TODO left in a doc, a module with heavy churn since the last refine report whose `scope` covered it. That report's scope counts as unchanged by the `result` comparison in `practices/reports.md`. An item never links the asset it came from, per the agenda's inbox independence rule. Skip an asset that is archived or reference material, one whose open work the agenda or a doc already carries, and one the evidence shows was executed or absorbed. Where it is unclear whether an asset still wants action, ask in step 3. Insert each new item by its priority, per the agenda rules, and move no existing item.

Challenge a section whose date has fallen well behind the rest. Judge "behind" by the project's own pace, never by the calendar: compare against the other sections' dates and the spacing of recent commits, since a project can sit idle for months and then move daily. A quiet section in an idle project is not stale. One left behind while its neighbors kept moving likely is. Ask in step 3 whether to keep it or drop it, and act only on the answer. Keeping it bumps its date.

Group loose items into sections, extract an oversized section, and fold back a shrunken one, as the agenda rules describe. Grouping keeps each item's relative order and dates the new section today.

## 5. Generalize
Rewrite surviving scripts and docs so an agent on another task can use them: strip one-off paths, task-specific names, and hardcoded inputs in favor of arguments. Leave files that are already general unedited.

Move stray data files out of `scripts/` into `scripts/data/<script-name>/` and repoint the scripts that read them.

### 5a. Mine the session history
Read `mine.md` beside this file and script the work past sessions did by hand, as it describes.

## 6. Index
Create or repair `scripts/index.md` and `doc/index.md` in the format `practices/agent-dir.md` gives. Add the step 5 scripts and drop lines whose file is gone.

## 7. Ignore rules
Make `.agent/.gitignore` the single line `*`.

Files already committed stay tracked until the user untracks them. Never touch the git index.

## 8. Project memory
Update project memory to match the tidied directory and cut its bloat: stale paths, rules the user CLAUDE.md already carries, prose that restates itself.

## Report
List the moves, deletions, and generalized files. Report the agenda items dropped and added as `Chat reports` in `practices/agenda.md` describes. Name each step 5 script and the procedure it replaces, give transcripts skimmed against transcripts skipped, and flag anything left in place because its fate was unclear.
