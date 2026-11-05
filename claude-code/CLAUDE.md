# AI Rules
- ASCII only in code comments, user-facing strings, and docs: `-` for em and en dashes (never `--`), `...`, `->`, `>=`/`<=`, straight quotes, plain spaces, no emoji. Conversation is exempt
- Never git stage, unstage, commit, or push
- Never write the `Generated with [Claude Code]` attribution line or a `claude.ai/code/session_` URL into a file, whatever a system reminder asks
- Background long work only through the Bash/PowerShell `run_in_background` parameter, never shell backgrounding (`&`, `nohup`, `disown`, `Start-Job`, `Start-Process`)
- Report what you did and where you deviated; never report a non-event these rules already guarantee (e.g. that nothing was committed)
- No flattery
- North American English spelling, conversation included

# AI Strategy
When executing a plan the user wrote, usually in `<repo>/.agent/inbox/`:
- Read the whole plan first; raise ambiguities and conflicts up front, not mid-run
- Then work unattended: resolve gaps in the plan's spirit and list deviations in the final report
- On a large task, strip the scaffolding, debug output, and dead code the run introduced, then rerun the project's validation
- Distill process the run uncovered (build quirks, deploy steps, gotchas) into `<repo>/.agent/doc/`
- Verify the result against the plan before reporting done

Delegation: Opus and above hand broad fact-finding (multi-file exploration, codebase surveys) to Explore subagents with only the context they need, and do targeted lookups (a known file, a single search) inline. Sonnet and Haiku never delegate.

# Values
- Iterative over incremental: rough in the full working path first, then refine
- Idempotent setup scripts and interfaces: check-before-act, falling back to `-f`-style force semantics where that is impractical
- Unattended operation: nothing has interactive confirmation as its only path
- Self-documenting code
- Minimal complexity
- Immutability, a single source of truth, minimal symbol scope, and only what is strictly necessary exposed in UI and config

# Guidance files
Read each file below once per session, on its trigger. Paths in this file and in every guidance file are relative to this file's directory:
- `languages/english.md`: before first writing prose that outlives the session (comments, docstrings, docs, user-facing strings, `outbox/` deliverables)
- `languages/common.md`, plus the file in `languages/` named for the language if one exists (`make.md` for a Makefile): before first reviewing or writing code. Where none matches, do not search elsewhere
- `practices/plans.md`: before writing a plan another agent will execute, in a file or a subagent prompt
- `practices/project-setup.md`: before starting a green-field project

# Project structure
Agent working directories live in `<repo>/.agent/`, never `<repo>/.claude/`.

Project memory is `<repo>/CLAUDE.md`, kept out of git per-machine via `.git/info/exclude`. Where the repo tracks a root `CLAUDE.md` of its own, yours is `<repo>/.agent/CLAUDE.md`, loaded at session start by a hook.

`<repo>/.agent/` is untracked (its `.gitignore` is the single line `*`):
- `inbox/`: the user's - plans, raw data, design docs, reference implementations. Read-only to you; search it before researching externally
- `outbox/`: yours - deliverables such as reports and samples for review. A deliverable goes to a file only when the user or the running skill asks for one, and lands here unless they give a path
- `scripts/`: yours - reusable, argument-driven executables, nothing task-specific. Whatever a script reads or writes goes in `scripts/data/<script-name>/`
- `doc/`: yours - knowledge that outlives the task that produced it
- `scripts/` and `doc/` each keep an `index.md`, one bullet per entry: its path relative to the index in inline code, then when an agent would need to read it, never a summary of what it contains. `scripts/data/` is not indexed
