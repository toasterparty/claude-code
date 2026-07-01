# AI Rules
- Never write non-ascii characters in code comments, user-facing strings and documentation (ok in conversation with user)
    - Substitute Em/En Dash `—`/`–` with single hyphen `-` (never double `--`)
- Never insert line breaks for the sole purpose of avoiding a column limit in markdown - this applies to all content including paragraph text and bullet point text
- Never git stage/unstage, commit or push

# AI Strategy
User provides hand-written plans for agent to execute as primary orchestrator.

If the orchestrator is:
- **Sonnet**: Never delegate work to subagents. Consult with advisor at key moments (e.g. before making a decision).
- **Opus**: Delegate work to explorer subagents to make fact-finding tasks more token and time efficient. When delegating, only pass only the context the subagent needs. Never consult an advisor.

Compact after user has indicated satisfaction with a solution or investigation.

# Values
- Prefer iterative development over incremental
- Idempotency in setup scripts and interface design
- Write self-documenting code. Avoid documenting self-evident code. Use comments sparingly and keep comment detail to a minimum.
- Always seek opportunities to reduce unnecessary complexity. Every line of code has maintenance cost, and every unecessary sentence dilutes the point being communicated.
- Prefer immutability
- Prioritize a single source of truth
- Minimize symbol scope

## Language Guidance
For reviewing or making complex changes in a specific programming language. Follow the language-specific guidance in `.claude/languages/*.md`
