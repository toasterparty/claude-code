# AI Rules
- Never use non-ascii in code comments, user-facing strings, or docs (fine in conversation)
    - Replace Em/En Dash (U+2014/U+2013) with `-` (never `--`)
- Never wrap lines to fit a column limit in markdown (paragraphs and bullets included)
- Never git stage/unstage, commit or push
- Never leave unrequested markdown files in the repo; a requested deliverable goes to `<repo>/.agent/outbox/`
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
- Write self-documenting code (see Comments)
- Minimize unnecessary complexity: every line costs maintenance, every unneeded sentence dilutes the point
- Prefer immutability
- Prioritize a single source of truth
    - For docs too: minimize how many places must change when the implementation does - self-describing code beats invariant docs beats narrative docs
- Minimize symbol scope
- Expose only what's strictly necessary in UI and config interfaces

## Comments
Prefer none - names, types, and structure should carry the meaning. Write one only for a fact the code cannot state itself, and the best kind is counterintuitive: it defends this implementation against the simpler one a reader would otherwise reach for.
- Comment why, never what; drop any comment a reader could re-derive from the code beside it
- One or two lines - a fact that needs a paragraph belongs in a design doc, not the source
- Never narrate the implementation journey (alternatives tried, bugs chased, how an earlier draft failed); the maintainer inherits the code, not the road to it - route that story to the final report instead
- Stop at the surprising fact; detail past it only gets skimmed and remembered by no one
- Docstrings follow the same rules; they state the contract of a public API (inputs, outputs, invariants), never the implementation
- Good: `timeout = 250  # Cloudflare drops idle connections at 300s`. Weak: `# set the timeout` (restates code) or `# was 500, kept dropping` (journey)
- Final pass before reporting done: reread the diff and delete any comment that fails these rules - comments are written hot but read cold

## Language Guidance
Before reviewing code or creating a new file or function in a language, read the matching file in `languages/` next to this file. Rules shared across all languages:
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
- `scripts/`: Yours - scripts worth keeping, written to be generally reusable rather than task-specific.
- `doc/`: Yours - durable knowledge that outlives the task that produced it.
- `scripts/` and `doc/` each keep an `index.md`: one line per entry - the filename, then when a future agent would need it.
