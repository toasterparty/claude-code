# AI Rules
- Never use non-ascii in code comments, user-facing strings, or docs (fine in conversation)
    - Replace Em/En Dash (U+2014/U+2013) with `-` (never `--`)
- Before first writing prose that outlives the session - code comments, docstrings, docs, markdown, user-facing strings, `outbox/` deliverables - read `languages/english.md` next to this file; once read, don't reread it
- Never git stage/unstage, commit or push
- Never leave unrequested markdown files outside `<repo>/.agent/`; a requested deliverable goes to `<repo>/.agent/outbox/`
- Report the actions you took and where you deviated; never report a non-event these rules already guarantee (e.g. that nothing was committed)
- No flattery of the user (risk of patronization)

# AI Strategy
User hand-writes plans (often in `<repo>/.agent/inbox/`) for the Orchestrator (main thread agent) to execute.

Executing a plan:
- Read the whole plan before acting; raise ambiguities and conflicts up front, not mid-run
- Once underway, work unattended: resolve gaps in line with the plan's intent and list any deviations in the final report
- On a large task, strip the scaffolding, debug output, and dead code the run introduced, then rerun the project's autonomous validation to prove the cleanup changed no behavior
- Distill undocumented process the run uncovered (build quirks, deploy steps, gotchas) into `<repo>/.agent/doc/`
- Verify the result against the plan before reporting done

Orchestrator behavior by model:
- **Opus and above**: Delegate broad fact-finding (multi-file exploration, codebase surveys) to Explore subagents, passing only the context needed - this keeps bulk reads out of the main context. Do targeted lookups (a known file, a single search) inline; an agent spawn costs more than it saves there.
- **Sonnet/Haiku**: Never delegate to subagents.

# Values
- Prefer iterative development over incremental: rough in the full working path first, then refine - don't perfect one piece at a time
- Idempotency in setup scripts and interface design: prefer check-before-act, falling back to `-f`-style (force) semantics when that isn't practical
- Design for unattended operation: nothing should have interactive confirmation as its only path
- Write self-documenting code (see `languages/english.md`)
- Minimize unnecessary complexity: every line costs maintenance, every unneeded sentence dilutes the point
- Prefer immutability
- Prioritize a single source of truth
- Minimize symbol scope
- Expose only what's strictly necessary in UI and config interfaces

## Language Guidance
Before first reviewing or writing code in a language each session, read the matching file in `languages/` next to this file; once read, don't reread it. If no file matches the language, apply only the shared rules below - don't search elsewhere:
- Guard clauses for edge cases; keep the success path unindented at the bottom
- Prefer `return`/`break`/`continue` over `else` blocks
- Keep indentation to 1-3 levels; never 5+
- Keep functions small; extract standalone logic into private functions

For green-field projects, prefer a top-level Makefile; dev and CI/CD invoke the same make targets (see `make.md`).

# Project structure
Agent working directories live in `<repo>/.agent/`, never `<repo>/.claude/`.

Project memory is `<repo>/CLAUDE.md`, which Claude Code loads natively, kept per-machine by `.git/info/exclude` rather than a tracked ignore rule. Where the repo already tracks a root `CLAUDE.md` of its own, yours falls back to `<repo>/.agent/CLAUDE.md`; **read that fallback first thing in a session, before acting on the prompt** - nothing auto-loads it.

Nothing under `<repo>/.agent/` is tracked; it holds a `.gitignore` whose only line is `*`.
- `inbox/`: User-owned drop point - plans, raw data, design docs, reference implementations. Read-only to you; search it before researching externally.
- `outbox/`: Yours - deliverables (reports, samples for review). A deliverable the user names without a path belongs here; prefer it to the conversation for large output or anything the user will copy-paste.
- `scripts/`: Yours - scripts worth keeping, written to be generally reusable rather than task-specific. Executables only; whatever a script reads or writes goes in `scripts/data/<script-name>/`.
- `doc/`: Yours - durable knowledge that outlives the task that produced it.
- `scripts/` and `doc/` each keep an `index.md`: one line per entry - the filename, then when a future agent would need it. `scripts/data/` is not indexed.
