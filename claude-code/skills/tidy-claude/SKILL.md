---
name: tidy-claude
description: Tidy the current repository's .agent/ directory into the standard inbox/outbox/scripts/doc layout - scaffold the dirs, migrate legacy ones including the old .claude/ layout, archive finished work, purge regenerable junk, repair the indexes.
disable-model-invocation: true
---

Bring `<repo>/.agent/` into the layout the user CLAUDE.md defines, running the passes below in order.

Survey with one recursive listing carrying sizes and dates, and open a file only when its name, size, and location leave its fate open. Batch moves and deletes into as few shell calls as possible rather than one tool call per file.

## Scope
Touch only the four layout dirs under `.agent/` and the legacy locations they replace: `<repo>/.claude/{inbox,outbox,scripts,doc}/` and the older `plans/`, `reference/`, `agent/`. Everything else in `<repo>/.claude/` is Claude Code's own config, and every write there costs a permission prompt no rule can suppress. Remove a legacy dir from `.claude/` only once its contents are safely moved.

Never edit a file under `inbox/`. Moving a whole file out of a legacy location is the one change allowed against user content.

## 1. Create the layout
Create whichever of the four layout dirs are missing, and keep them even when empty: an empty `inbox/` tells the user where to drop the next plan. Subdirectories, `_archive/` and `scripts/data/` included, appear only on first use.

## 2. Migrate legacy layouts
- `.claude/{inbox,outbox,scripts,doc}/*` -> the matching dir under `.agent/`, subdirectories intact
- `.claude/CLAUDE.md` -> project memory, at the path the user CLAUDE.md gives
- `reference/*` -> `inbox/`
- `plans/*` -> `inbox/`, and its `archive/` or `_archive/` subdirs -> `inbox/_archive/`
- `agent/` scripts -> `scripts/` if worth reusing, otherwise delete
- `agent/` notes that still teach something -> `doc/`
- agent-authored reports in any legacy dir -> `outbox/_archive/`

## 3. Resolve ambiguity
A file is archived once its work is finished. Ambiguous means neither the file, the repo, nor git history settles that: a plan with unchecked boxes, a report on an unmerged branch, a script whose target still exists.

Collect these during the survey and ask them in one AskUserQuestion batch before the first destructive move, one question per file or related group, each option stating the action it triggers. Whatever the user leaves unresolved stays where it is. Never archive or delete on a guess.

## 4. Purge and archive
Delete regenerable artifacts outright: caches, `__pycache__`, virtualenvs, build outputs, logs, re-downloadable binaries. `scripts/data/` collects them fastest.

Everything else keeps its bytes. Never delete non-regenerable data (captured baselines, recorded measurements, one-off datasets), whatever its size. Files tied to a resolved issue move into an `_archive/` inside their current directory.

## 5. Generalize
Rewrite surviving scripts and docs so an agent on another task can use them: strip one-off paths, task-specific names, and hardcoded inputs in favor of arguments. Leave files that are already general unedited.

Move stray data files out of `scripts/` into `scripts/data/<script-name>/` and repoint the scripts that read them.

### 5a. Mine the session history
Past sessions have done by hand what a script should do. Find that work and script it.

Transcripts live at `<claude home>/projects/<repo path with every separator and colon replaced by `-`>/<session-id>.jsonl`, with subagent transcripts in a sidecar directory named for the session. `<claude home>` is `$CLAUDE_CONFIG_DIR` when set, otherwise `~/.claude`.

Delegate the skim to an Explore subagent, handing it the exact files and byte offsets from the ledger. Have it filter the JSONL down to user messages and tool-call inputs before reading, since tool results are the bulk and rarely matter. Ask back for only each procedure, the commands that carried it out, and the arguments a script would take.

Worth a script: a multi-command procedure repeated across sessions or rebuilt each time, an invocation that took several attempts (quoting, platform differences, pagination, auth), anything the user had to correct. Not worth one: anything a single tool call solves.

Write each new script under the same rules as the generalized ones: argument-driven, idempotent, non-interactive, no repo-specific path.

### 5b. Skim ledger
Cost must track new conversation, not accumulated history, so nothing is skimmed twice.

The ledger is `scripts/data/tidy-claude/skimmed.tsv`: one line per transcript, `<session-id>`, tab, its size in bytes when skimmed. List the transcript directory with sizes and compare:

- absent, or smaller than recorded (rotated) - skim the whole file
- larger - skim only the tail, from `tail -c +<recorded + 1>`
- equal - skip without opening

Record sizes from that listing, never from a fresh stat after the skim, so bytes appended mid-run (the tidying session's own transcript among them) are picked up next time.

A first run against a long history is the expensive one. Work newest-first, stop when findings dry up, and record only what was skimmed, leaving the rest pending.

## 6. Index
Create or repair `scripts/index.md` and `doc/index.md` in the format the user CLAUDE.md gives. Add the step 5 scripts and drop lines whose file is gone.

## 7. Ignore rules
Make `.agent/.gitignore` the single line `*`, dropping any un-ignore exceptions a legacy layout left behind, `!CLAUDE.md` included.

If `git ls-files --error-unmatch CLAUDE.md` fails, append `CLAUDE.md` to `.git/info/exclude` unless already present. If it succeeds, the root `CLAUDE.md` is the team's: leave it and the ignore rules untouched.

Files already committed stay tracked until the user untracks them. Never touch the git index.

## 8. Project memory
Update project memory to match the tidied directory and cut its bloat: stale paths, rules the user CLAUDE.md already carries, prose that restates itself.

## Report
List the moves, deletions, and generalized files. Name each step 5 script and the procedure it replaces, give transcripts skimmed against transcripts skipped, and flag anything left in place because its fate was unclear.
