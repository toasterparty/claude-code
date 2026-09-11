# AI Rules
- ASCII only in code comments, user-facing strings, and docs: `-` for em and en dashes, never `--`. Conversation is exempt
- Before first writing prose that outlives the session (comments, docstrings, docs, user-facing strings, `outbox/` deliverables), read `languages/english.md` beside this file. Once per session
- Never git stage, unstage, commit, or push
- Background long work only through the Bash/PowerShell `run_in_background` parameter. Shell backgrounding (`&`, `nohup`, `disown`, `Start-Job`, `Start-Process`) orphans the process: each tool call gets a fresh shell, so nothing notifies on it and `TaskOutput`/`TaskStop` cannot reach it
- Report what you did and where you deviated; never report a non-event these rules already guarantee (e.g. that nothing was committed)
- No flattery

# AI Strategy
The user hand-writes plans, usually in `<repo>/.agent/inbox/`, for the Orchestrator (the main-thread agent) to execute:
- Read the whole plan first; raise ambiguities and conflicts up front, not mid-run
- Then work unattended: resolve gaps in the plan's spirit and list deviations in the final report
- On a large task, strip the scaffolding, debug output, and dead code the run introduced, then rerun the project's validation to prove the cleanup changed no behavior
- Distill process the run uncovered (build quirks, deploy steps, gotchas) into `<repo>/.agent/doc/`
- Verify the result against the plan before reporting done

Delegation: Opus and above hand broad fact-finding (multi-file exploration, codebase surveys) to Explore subagents with only the context they need, keeping bulk reads out of the main context, and do targeted lookups (a known file, a single search) inline. Sonnet and Haiku never delegate.

# Values
- Iterative over incremental: rough in the full working path first, then refine
- Idempotent setup scripts and interfaces: check-before-act, falling back to `-f`-style force semantics where that is impractical
- Unattended operation: nothing has interactive confirmation as its only path
- Self-documenting code
- Minimal complexity: every line costs maintenance
- Immutability, a single source of truth, minimal symbol scope, and only what is strictly necessary exposed in UI and config

## Language Guidance
Before first reviewing or writing code each session, read `languages/common.md` beside this file plus the file matching the language, if one exists; before the first test, `languages/testing.md` too. Read each once. Where no file matches the language, `common.md` is the whole of it - do not search elsewhere.

Green-field projects get a top-level Makefile; dev and CI/CD invoke the same targets (see `languages/make.md`).

# Project structure
Agent working directories live in `<repo>/.agent/`, never `<repo>/.claude/`.

Project memory is `<repo>/CLAUDE.md`, loaded natively and kept out of git per-machine via `.git/info/exclude`. Where the repo tracks a root `CLAUDE.md` of its own, yours is `<repo>/.agent/CLAUDE.md`: **read it first thing in a session, before acting on the prompt**, since nothing auto-loads it.

`<repo>/.agent/` is untracked (its `.gitignore` is the single line `*`):
- `inbox/`: the user's - plans, raw data, design docs, reference implementations. Read-only to you; search it before researching externally
- `outbox/`: yours - deliverables such as reports and samples for review. A deliverable the user names without a path lands here; prefer it to the conversation for large output or anything the user will copy-paste. No unrequested markdown lands anywhere outside `.agent/`
- `scripts/`: yours - reusable, argument-driven executables, nothing task-specific. Whatever a script reads or writes goes in `scripts/data/<script-name>/`
- `doc/`: yours - knowledge that outlives the task that produced it
- `scripts/` and `doc/` each keep an `index.md`: one line per entry, the filename then when a future agent would need it. `scripts/data/` is not indexed
