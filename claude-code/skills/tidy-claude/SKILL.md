---
name: tidy-claude
description: Tidy the current repository's .agent/ directory into the standard inbox/outbox/scripts/doc layout - scaffold the dirs, migrate legacy ones including the old .claude/ layout, archive finished work, purge regenerable junk, repair the indexes.
disable-model-invocation: true
---

Bring `<repo>/.agent/` in the current repository into the layout the user CLAUDE.md defines. Survey the whole directory first, then run the passes below in order.

## Scope
Touch only the four layout dirs (`inbox/`, `outbox/`, `scripts/`, `doc/`) under `.agent/`, plus the legacy locations they replace: `<repo>/.claude/{inbox,outbox,scripts,doc}/` and the older `plans/`, `reference/`, `agent/`.

Otherwise leave `<repo>/.claude/` alone - it holds Claude Code's own config (`settings*.json`, `skills/`, `agents/`, `commands/`, `hooks/`, lock files), and every write under it costs a permission prompt that no rule can suppress. Remove a legacy layout dir from `.claude/` only once its contents are safely moved.

Never edit a file under `inbox/`; migrating a whole file out of a legacy location is the one move allowed against user content.

## 1. Create the layout
Ensure all four layout dirs exist under `.agent/`, creating whichever are missing. Leave a dir in place even if nothing lands in it - an empty `inbox/` is how the user learns where to drop the next plan. Subdirectories, `_archive/` and `scripts/data/` included, are still created on first use.

## 2. Migrate legacy layouts
- `.claude/inbox/*`, `.claude/outbox/*`, `.claude/scripts/*`, `.claude/doc/*` -> the matching dir under `.agent/`, subdirectories intact
- `.claude/CLAUDE.md` -> `<repo>/CLAUDE.md`, or `<repo>/.agent/CLAUDE.md` if the repo already tracks a root `CLAUDE.md` of its own
- `reference/*` -> `inbox/`
- `plans/*` -> `inbox/`, and its `archive/` or `_archive/` subdirs -> `inbox/_archive/`
- `agent/` scripts -> `scripts/` if worth reusing, otherwise delete
- `agent/` notes that still teach something -> `doc/`
- agent-authored reports in any legacy dir -> `outbox/_archive/`

## 3. Resolve ambiguity
Whether a file gets archived turns on whether the work it belongs to is finished, and the repo frequently does not say. Ambiguous means you cannot settle it from the file, the surrounding repo, or git history: a plan with unchecked boxes, a report on a branch that never merged, a script whose target still exists.

Collect these during the survey and put them to the user in one batch with AskUserQuestion, before the first destructive move - one question per file or per obviously-related group, each spelling out what you would do with each answer. Do not ask about cases you can settle yourself.

Anything the user does not resolve stays exactly where it is. Never archive or delete on a guess.

## 4. Purge and archive
Delete regenerable artifacts outright: caches, `__pycache__`, virtualenvs, build outputs, logs, re-downloadable binaries. Archiving them just relocates wasted space. `scripts/data/` is where these accumulate fastest, so sweep it here.

Everything else keeps its bytes. Non-regenerable data (captured baselines, recorded measurements, one-off datasets) is never deleted regardless of size, and files tied to a resolved issue move into an `_archive/` inside the directory they already live in.

## 5. Generalize
Rewrite surviving scripts and docs so an agent on a different task can use them: strip one-off paths, task-specific names, and hardcoded inputs; take arguments instead.

`scripts/` holds executables and nothing else. Whatever a script reads or writes - fixtures, captured output, ledgers, scratch state - belongs under `scripts/data/<script-name>/`, so that `ls scripts/` and `index.md` stay a list of capabilities. Move stray data files there and repoint the scripts that read them.

### 5a. Mine the session history
Past sessions in this repo have already done by hand what a script should be doing. Find that work and write the script.

Transcripts for the current repo live at `<claude home>/projects/<repo path with every separator and colon replaced by `-`>/<session-id>.jsonl` - claude home is `$CLAUDE_DIR` when set, otherwise `~/.claude` - with subagent transcripts in a sidecar directory named for the session.

Delegate the skim to an Explore subagent. The transcripts run to megabytes and the findings to a paragraph; none of that bulk belongs in the orchestrator's context. Give it the exact files and byte offsets from the ledger below, and ask it back for only the procedure, the commands that carried it out, and what a script would need to take as arguments.

What is worth a script: a multi-command procedure repeated across sessions or rebuilt from scratch each time; an invocation that took several attempts to get right (quoting, platform differences, pagination, auth); anything the user had to correct. What is not: anything a single tool call already solves.

Write each new script into `scripts/` under the same rules as the ones you generalized - argument-driven, idempotent, non-interactive, no path that assumes this repo - with its data under `scripts/data/<script-name>/`. Step 6 indexes them.

### 5b. Skim ledger
Cost has to stay proportional to new conversation, not to accumulated history, so record what was skimmed and never open it twice.

The ledger is `scripts/data/tidy-claude/skimmed.tsv`, one line per transcript: `<session-id>`, tab, the file's size in bytes at the moment it was skimmed. Take a listing of the transcript directory and compare:

- absent from the ledger, or smaller than its recorded size (rotated) - skim the whole file
- larger than its recorded size - skim only the tail, from `tail -c +<recorded + 1>`
- equal - skip it entirely; do not open it

Write the ledger from the sizes in that listing, not from a fresh stat after the agent returns, so anything appended mid-run is picked up next time. The session doing the tidying is itself being appended to; that is the case this rule exists for.

A first run against a long history is the expensive one. Work newest-first, stop when the findings dry up, and record only the transcripts actually skimmed - the rest stay pending for a later run rather than being silently marked done.

## 6. Index
Create or repair `index.md` in `scripts/` and `doc/` - one line per entry, the filename then when a future agent would need it. Add the scripts written in step 5. Drop lines whose file no longer exists. `scripts/data/` is never indexed.

## 7. Ignore rules
Ensure `.agent/.gitignore` exists and its only line is `*`, so the directory is fully untracked. Nothing under `.agent/` is tracked deliberately, so it needs no un-ignore exceptions - drop any a legacy layout left behind, along with any obsolete `!CLAUDE.md`.

Keep project memory out of git per-clone rather than through a tracked ignore rule: if `git ls-files --error-unmatch CLAUDE.md` fails, append `CLAUDE.md` to `.git/info/exclude` unless that line is already present. If it succeeds the repo tracks its own root `CLAUDE.md` - leave both the file and the ignore rules untouched, because that file is the team's.

Files already committed stay tracked until the user untracks them. Never touch the git index.

## 8. Project memory
Update project memory to match the tidied directory, and cut its token bloat: stale paths, rules the user CLAUDE.md already carries, prose that restates itself. That file is `<repo>/CLAUDE.md`, except where a tracked root `CLAUDE.md` forced yours to `<repo>/.agent/CLAUDE.md`.

## Report
List the moves, the deletions, and the files you generalized. Name each script written in step 5 and the procedure it replaces, and say how many transcripts were skimmed against how many the ledger let you skip. Flag anything left in place because its fate was unclear.
