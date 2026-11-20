---
name: tidy
description: Tidy the current repository's .agent/ directory into the standard inbox/outbox/reports/scripts/doc layout - scaffold the dirs, migrate legacy ones including the old .claude/ layout and CLAUDE.md project memory, archive finished work, drop agenda items already addressed, add agenda items for unaddressed inbox assets, purge regenerable junk, repair the indexes.
disable-model-invocation: true
---

Bring `<repo>/.agent/` into the layout the user CLAUDE.md defines, running the passes below in order.

Survey with one recursive listing carrying sizes and dates, and open a file only when its name, size, and location leave its fate open. Batch moves and deletes into as few shell calls as possible rather than one tool call per file.

## Scope
Touch only the five layout dirs and the `git/` scratch dir under `.agent/`, the agenda, the project instruction files, and the legacy locations they replace: `<repo>/.claude/{inbox,outbox,scripts,doc}/`, the older `plans/`, `reference/`, `agent/`, and `CLAUDE.md` at the repo root, in `.agent/`, or in `.claude/`. Leave everything else in `<repo>/.claude/` alone. Remove a legacy dir from `.claude/` only once its contents are safely moved.

Never edit a file under `inbox/`. Moving a whole file out of a legacy location is the one change allowed against user content.

## 1. Create the layout
Create whichever of the five layout dirs (`inbox/`, `outbox/`, `reports/`, `scripts/`, `doc/`) are missing, and keep them even when empty. Subdirectories, `_archive/` and `scripts/data/` included, appear only on first use.

## 2. Migrate legacy layouts
- `.claude/{inbox,outbox,scripts,doc}/*` -> the matching dir under `.agent/`, subdirectories intact
- `.agent/CLAUDE.md`, `.claude/CLAUDE.md`, and an untracked root `CLAUDE.md` -> `.agent/AGENTS.md`, appending to it where it already exists
- a tracked root `CLAUDE.md` -> `AGENTS.md`, only on the user's answer in step 3, appending to a tracked `AGENTS.md` where one exists. Move it with plain `mv`, leaving the rename for the user to stage
- `scripts/data/tidy-claude/` -> `scripts/data/tidy/`, merging into it where it exists
- `reference/*` -> `inbox/`
- `plans/*` -> `inbox/`, and its `archive/` or `_archive/` subdirs -> `inbox/_archive/`
- `agent/` scripts -> `scripts/` if worth reusing, otherwise delete
- `agent/` notes that still teach something -> `doc/`
- skill reports written before `practices/reports.md`, such as `outbox/refine/`, `outbox/consult/`, and `refine-*` or `review-*` files, archived or not -> `reports/_archive/`, contents unchanged, each name prefixed with its old subdir under `outbox/` (minus any `_archive/` level) so names cannot collide, as in `outbox/refine/_archive/202611021811-b357e5f.md` -> `reports/_archive/refine-202611021811-b357e5f.md`. Give each review item or open question still open in them an agenda item tagged `User Decision`, unless one already covers it: an item not marked `[resolved: ...]`, `[dropped: ...]`, or `[moved: ...]`, whose code or question still stands. Repoint every agenda link to a moved file
- other agent-authored reports in any legacy dir -> `outbox/_archive/`

## 3. Resolve ambiguity
A file is archived once its work is finished. Ambiguous means neither the file, the repo, nor git history settles that: a plan with unchecked boxes, a report on an unmerged branch, a script whose target still exists.

A tracked root `CLAUDE.md` always counts as ambiguous: rename it only in a repo the user owns, and only the user can say whether they own it, since a work repo's remote names an org rather than an owner. Other developers' repos keep their `CLAUDE.md`.

Collect these during the survey, agenda items of unproven status and inbox assets of unclear status (step 4a) among them, and ask them in one AskUserQuestion batch before the first destructive move, one question per file or related group, each option stating the action it triggers. Whatever the user leaves unresolved stays where it is. Never archive or delete on a guess.

## 4. Purge and archive
Delete regenerable artifacts outright: caches, `__pycache__`, virtualenvs, build outputs, logs, re-downloadable binaries, and every clone under `git/` except the persistent ones `practices/scratch-clones.md` describes. `scripts/data/` collects them fastest.

Everything else keeps its bytes. Never delete non-regenerable data (captured baselines, recorded measurements, one-off datasets), whatever its size. Files tied to a resolved issue move into an `_archive/` inside their current directory. A report in `reports/` whose `opened` IDs all appear in the agenda log moves to `reports/_archive/`.

## 4a. Reconcile the agenda
Read `practices/agenda.md` first. Then check the agenda both ways against `inbox/`, `outbox/`, `reports/`, `doc/`, the repo, and git history.

Drop an item once the evidence proves it addressed: a commit containing its change, the described behavior or file present in the repo, a plan whose boxes are all checked and whose changes landed, a decision recorded in a doc or plan. An item with only partial or circumstantial evidence goes to step 3, and is dropped on the user's confirmation. Never drop on a guess. Log every drop and clear the `blocked by` tags that named it, as the agenda rules describe, and stamp `open @<HEAD>` on each item checked and found still open.

Bring every item to the agenda's item format. Give each item without an ID a new one, taking them all from one `next-id.sh --count <n>` call. Turn a dependency or user task stated in prose into its tag, such as "after the redesign" into `blocked by` the redesign's ID, or "have the user confirm in game" into `User Task`. Cut an item that runs past one line to a headline, moving its context into sub-bullets, or into the linked doc where it is longer than a few short lines.

Add an item for each asset that shows open work and has none: an `inbox/` plan or design doc nobody executed, raw data nobody analyzed, a report with an `opened` ID missing from both the agenda and its log, a TODO left in a doc, a module with heavy churn since the last refine report whose `scope` covered it. Skip an asset that is archived, already linked from an item, or reference material, and an asset the evidence shows was executed or absorbed. Where it is unclear whether an asset still wants action, ask in step 3. Insert each new item by its priority, per the agenda rules, and move no existing item.

Challenge a section whose date has fallen well behind the rest. Judge "behind" by the project's own pace, never by the calendar: compare against the other sections' dates and the spacing of recent commits, since a project can sit idle for months and then move daily. A quiet section in an idle project is not stale. One left behind while its neighbors kept moving likely is. Ask in step 3 whether to keep it or drop it, and act only on the answer. Keeping it bumps its date.

Group loose items into sections, extract an oversized section, and fold back a shrunken one, as the agenda rules describe. Grouping keeps each item's relative order and dates the new section today.

## 5. Generalize
Rewrite surviving scripts and docs so an agent on another task can use them: strip one-off paths, task-specific names, and hardcoded inputs in favor of arguments. Leave files that are already general unedited.

Move stray data files out of `scripts/` into `scripts/data/<script-name>/` and repoint the scripts that read them.

### 5a. Mine the session history
Script the work past sessions did by hand.

Transcripts live at `<claude home>/projects/<repo path with every separator and colon replaced by `-`>/<session-id>.jsonl`, with subagent transcripts in a sidecar directory named for the session. `<claude home>` is `$CLAUDE_CONFIG_DIR` when set, otherwise `~/.claude`.

Opus and above delegate the skim to an Explore subagent, handing it the exact files and byte offsets from the ledger. Filter the JSONL down to user messages and tool-call inputs before reading. Collect only each procedure, the commands that carried it out, and the arguments a script would take.

Worth a script: a multi-command procedure repeated across sessions or rebuilt each time, an invocation that took several attempts (quoting, platform differences, pagination, auth), anything the user had to correct. Not worth one: anything a single tool call solves.

Write each new script under the same rules as the generalized ones: argument-driven, idempotent, non-interactive, no repo-specific path.

### 5b. Skim ledger
Never skim the same bytes twice. The ledger is `scripts/data/tidy/skimmed.tsv`: one line per transcript, `<session-id>`, tab, its size in bytes when skimmed. List the transcript directory with sizes and compare:

- absent, or smaller than recorded (rotated) - skim the whole file
- larger - skim only the tail, from `tail -c +<recorded + 1>`
- equal - skip without opening

Record sizes from that listing, never from a fresh stat after the skim, so bytes appended mid-run (the tidying session's own transcript among them) are picked up next time.

A first run against a long history is the expensive one. Work newest-first, stop when findings dry up, and record only what was skimmed, leaving the rest pending.

## 6. Index
Create or repair `scripts/index.md` and `doc/index.md` in the format the user CLAUDE.md gives. Add the step 5 scripts and drop lines whose file is gone.

## 7. Ignore rules
Make `.agent/.gitignore` the single line `*`, dropping any un-ignore exceptions a legacy layout left behind, `!CLAUDE.md` included.

Once an untracked root `CLAUDE.md` has moved, delete its line from `.git/info/exclude`, which an older layout added to keep it out of git.

Files already committed stay tracked until the user untracks them. Never touch the git index.

## 8. Project memory
Update project memory to match the tidied directory and cut its bloat: stale paths, rules the user CLAUDE.md already carries, prose that restates itself.

## Report
List the moves, deletions, and generalized files, the agenda items dropped with their evidence, and the items added with their source asset. Name each step 5 script and the procedure it replaces, give transcripts skimmed against transcripts skipped, and flag anything left in place because its fate was unclear.
