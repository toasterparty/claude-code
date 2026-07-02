# AI Rules
- Never use non-ascii in code comments, user-facing strings, or docs (fine in conversation)
    - Replace Em/En Dash (U+2014/U+2013) with `-` (never `--`)
- Never wrap lines to fit a column limit in markdown (paragraphs and bullets included)
- Never git stage/unstage, commit or push

# AI Strategy
User hand-writes plans for the Orchestrator (main thread agent) to execute.

Orchestrator behavior by model:
- **Sonnet/Haiku**: Never delegate to subagents. Consult the advisor before key decisions.
- **Opus/Fable**: Delegate fact-finding to explorer subagents for token/time efficiency, passing only the context needed. Never consult the advisor.

# Values
- Prefer iterative development over incremental
- Idempotency in setup scripts and interface design: prefer check-before-act, falling back to `-f`-style (force) semantics when that isn't practical
- Write self-documenting code; comment sparingly and only on what isn't self-evident
- Minimize unnecessary complexity: every line costs maintenance, every unneeded sentence dilutes the point
- Prefer immutability
- Prioritize a single source of truth
- Minimize symbol scope

## Language Guidance
For language-specific review or complex changes, follow `languages/*.md`. Rules shared across all languages:
- Guard clauses for edge cases; keep the success path unindented at the bottom
- Prefer `return`/`break`/`continue` over `else` blocks
- Keep indentation to 1-3 levels; never 5+
- Keep functions small; extract standalone logic into private functions

# Project structure
- `<repo>/.claude/plans/`: User-authored plans; deleted by the user once satisfied
- `<repo>/.claude/agent/`: Yours, always gitignored - build up a persistent collection of useful scripts, artifacts, and information autonomously, without user involvement
- `<repo>/.claude/reference/`: Occasionally search here for docs relevant to the current task
- `<repo>/.claude/CLAUDE.md`: project-specific instructions, loaded alongside this global file, when present
