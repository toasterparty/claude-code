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
- **Opus and above**: Never consult the advisor. Delegate broad fact-finding (multi-file exploration, codebase surveys) to Explore subagents, passing only the context needed - this keeps bulk reads out of the main context. Do targeted lookups (a known file, a single search) inline; an agent spawn costs more than it saves there.
- **Sonnet/Haiku**: Never delegate to subagents. Consult the advisor before key decisions.

# Values
- Prefer iterative development over incremental: rough in the full working path first, then refine - don't perfect one piece at a time
- Idempotency in setup scripts and interface design: prefer check-before-act, falling back to `-f`-style (force) semantics when that isn't practical
- Design for unattended operation: nothing should have interactive confirmation as its only path
- Write self-documenting code; comment sparingly and only on what isn't self-evident
- Minimize unnecessary complexity: every line costs maintenance, every unneeded sentence dilutes the point
- Prefer immutability
- Prioritize a single source of truth
- Minimize symbol scope
- Expose only what's strictly necessary in UI and config interfaces

## Language Guidance
For language-specific review or complex changes, read the matching file in `languages/` next to this file. Rules shared across all languages:
- Guard clauses for edge cases; keep the success path unindented at the bottom
- Prefer `return`/`break`/`continue` over `else` blocks
- Keep indentation to 1-3 levels; never 5+
- Keep functions small; extract standalone logic into private functions

# Project structure
- `<repo>/.claude/plans/`: User-authored plans; deleted by the user once satisfied
- `<repo>/.claude/agent/`: Yours, always gitignored - maintain scripts, notes, and working state here autonomously; record anything a long run needs to survive context compaction
- `<repo>/.claude/reference/`: User-curated docs; search here before researching externally
