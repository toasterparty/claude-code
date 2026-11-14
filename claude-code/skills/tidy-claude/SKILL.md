---
name: tidy-claude
description: Tidy the current repository's .agent/ directory into the standard inbox/outbox/scripts/doc layout - scaffold the dirs, migrate legacy ones including the old .claude/ layout and CLAUDE.md project memory, archive finished work, purge regenerable junk, repair the indexes.
disable-model-invocation: true
---

Bring `<repo>/.agent/` into the layout the user CLAUDE.md defines, running the passes below in order.

Survey with one recursive listing carrying sizes and dates, and open a file only when its name, size, and location leave its fate open. Batch moves and deletes into as few shell calls as possible rather than one tool call per file.

## Scope
Touch only the four layout dirs under `.agent/`, the project instruction files, and the legacy locations they replace: `<repo>/.claude/{inbox,outbox,scripts,doc}/`, the older `plans/`, `reference/`, `agent/`, and `CLAUDE.md` at the repo root, in `.agent/`, or in `.claude/`. Leave everything else in `<repo>/.claude/` alone. Remove a legacy dir from `.claude/` only once its contents are safely moved.

Never edit a file under `inbox/`. Moving a whole file out of a legacy location is the one change allowed against user content.

## 1. Create the layout
Create whichever of the four layout dirs are missing, and keep them even when empty. Subdirectories, `_archive/` and `scripts/data/` included, appear only on first use.

## 2. Migrate legacy layouts
- `.claude/{inbox,outbox,scripts,doc}/*` -> the matching dir under `.agent/`, subdirectories intact
- `.agent/CLAUDE.md`, `.claude/CLAUDE.md`, and an untracked root `CLAUDE.md` -> `.agent/AGENTS.md`, appending to it where it already exists
- a tracked root `CLAUDE.md` -> `AGENTS.md`, only on the user's answer in step 3, appending to a tracked `AGENTS.md` where one exists. Move it with plain `mv`, leaving the rename for the user to stage
- `reference/*` -> `inbox/`
- `plans/*` -> `inbox/`, and its `archive/` or `_archive/` subdirs -> `inbox/_archive/`
- `agent/` scripts -> `scripts/` if worth reusing, otherwise delete
- `agent/` notes that still teach something -> `doc/`
- agent-authored reports in any legacy dir -> `outbox/_archive/`

## 3. Resolve ambiguity
A file is archived once its work is finished. Ambiguous means neither the file, the repo, nor git history settles that: a plan with unchecked boxes, a report on an unmerged branch, a script whose target still exists.

A tracked root `CLAUDE.md` always counts as ambiguous: rename it only in a repo the user owns, and only the user can say whether they own it, since a work repo's remote names an org rather than an owner. Other developers' repos keep their `CLAUDE.md`.

Collect these during the survey and ask them in one AskUserQuestion batch before the first destructive move, one question per file or related group, each option stating the action it triggers. Whatever the user leaves unresolved stays where it is. Never archive or delete on a guess.

## 4. Purge and archive
Delete regenerable artifacts outright: caches, `__pycache__`, virtualenvs, build outputs, logs, re-downloadable binaries. `scripts/data/` collects them fastest.

Everything else keeps its bytes. Never delete non-regenerable data (captured baselines, recorded measurements, one-off datasets), whatever its size. Files tied to a resolved issue move into an `_archive/` inside their current directory.

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
Never skim the same bytes twice. The ledger is `scripts/data/tidy-claude/skimmed.tsv`: one line per transcript, `<session-id>`, tab, its size in bytes when skimmed. List the transcript directory with sizes and compare:

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
List the moves, deletions, and generalized files. Name each step 5 script and the procedure it replaces, give transcripts skimmed against transcripts skipped, and flag anything left in place because its fate was unclear.
