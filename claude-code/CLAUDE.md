# AI Rules
- Never use non-ascii in code comments, user-facing strings, or docs (fine in conversation)
    - Replace Em/En Dash (U+2014/U+2013) with `-` (never `--`)
- Never wrap lines to fit a column limit in markdown (paragraphs and bullets included)
- Never git stage/unstage, commit or push

# AI Strategy
User hand-writes plans in `<repo>/.claude/plans/` for the Orchestrator (main thread agent) to execute.

Executing a plan:
- Read the whole plan before acting; raise ambiguities and conflicts up front, not mid-run
- Once underway, work unattended: resolve gaps in line with the plan's intent and list any deviations in the final report
- Verify the result against the plan before reporting done

Orchestrator behavior by model:
- **Opus and above**: Delegate broad fact-finding (multi-file exploration, codebase surveys) to Explore subagents, passing only the context needed - this keeps bulk reads out of the main context. Do targeted lookups (a known file, a single search) inline; an agent spawn costs more than it saves there.
- **Sonnet/Haiku**: Never delegate to subagents.

Consult the advisor (`/advisor`) before key decisions, unless it would run the same model as you (Opus -> Opus, Fable -> Fable) - a model advising itself adds cost without adding judgment.

# Values
- Prefer iterative development over incremental: rough in the full working path first, then refine - don't perfect one piece at a time
- Idempotency in setup scripts and interface design: prefer check-before-act, falling back to `-f`-style (force) semantics when that isn't practical
- Design for unattended operation: nothing should have interactive confirmation as its only path
- Write self-documenting code (see Comments)
- Minimize unnecessary complexity: every line costs maintenance, every unneeded sentence dilutes the point
- Prefer immutability
- Prioritize a single source of truth
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
- `<repo>/.claude/plans/`: User-authored plans; deleted by the user once satisfied
- `<repo>/.claude/agent/`: Yours, always gitignored - maintain scripts, notes, and working state here autonomously; record anything a long run needs to survive context compaction
- `<repo>/.claude/reference/`: User-curated docs; search here before researching externally
