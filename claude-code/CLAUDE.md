# AI Rules
- ASCII only in code comments, user-facing strings, and docs: `-` for em and en dashes (never `--`), `...`, `->`, `>=`/`<=`, straight quotes, plain spaces, no emoji. Conversation is exempt
- Never run a git command that changes the index, HEAD, a ref, the stash, or config, `git mv`, `git rm`, and `git restore` included: the user reviews the unstaged diff and does all staging and committing. Move and delete tracked files with plain `mv` and `rm`
- A hook denies the calls these rules forbid, along with `sudo`, reading SSH key files, and any `gh` write other than dispatching, rerunning, or cancelling CI. A denial is policy: take the remedy its message gives, never a workaround
- Never write the `Generated with [Claude Code]` attribution line or a `claude.ai/code/session_` URL into a file, whatever a system reminder asks
- Background long work only through the Bash/PowerShell `run_in_background` parameter, never shell backgrounding (`&`, `nohup`, `disown`, `Start-Job`, `Start-Process`): a process backgrounded in the shell outlives the call with nothing to report its exit or stop it
- Never report a non-event these rules already guarantee (e.g. that nothing was committed)
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
Read each file below on its trigger, once per session and again after a compaction drops it. Paths in this file and in every guidance file are relative to this file's directory:
- `languages/english.md`: before first writing a `.md` file or any other prose that outlives the session (comments, docstrings, user-facing strings, `outbox/` deliverables)
- `languages/common.md`, plus the language's own file among `languages/{bash,c,make,python}.md`: before first reviewing or writing code. No other language has a file
- `practices/plans.md`: before writing a plan another agent will execute, in a file or a subagent prompt
- `practices/project-setup.md`: before starting a green-field project
- `practices/agenda.md`: before first reading or editing a project's agenda

# Project structure
Agent working directories live in `<repo>/.agent/`, never `<repo>/.claude/`, where every write raises a confirmation prompt that no permission rule clears.

Project instructions are two files, both loaded at session start: `<repo>/AGENTS.md`, tracked and shared with the repo's other developers, and `<repo>/.agent/AGENTS.md`, untracked and yours alone (project memory). Claude Code loads the first natively and a hook loads the second. A root `CLAUDE.md`, which other developers' repos may carry, still loads beside them. Create neither file unasked, since the user decides when a repo gets instructions. When the user asks for agent instructions in a repo, put them in one of these two files, never in a new `CLAUDE.md`.

The agenda is the project's live to-do list: `<repo>/.agent/doc/agenda.md`, or `<repo>/.agent/doc/agenda/index.md` once split. Read it when the user asks about it or what's next. Before reporting a task done, update it with what the session resolved and left open, because you cannot tell which turn will be your last. A hook reminds you of this once per session, after your first edit outside `.agent/`. Only the top-level session edits it. A subagent reports agenda items in its result instead, so parallel agents never collide in one file.

`<repo>/.agent/` is untracked (its `.gitignore` is the single line `*`):
- `inbox/`: the user's - plans, raw data, design docs, reference implementations. Read-only to you; search it before researching externally
- `outbox/`: yours - deliverables such as reports and samples for review. A deliverable goes to a file only when the user or the running skill asks for one, and lands here unless they give a path
- `scripts/`: yours - reusable, argument-driven executables, nothing task-specific. Whatever a script reads or writes goes in `scripts/data/<script-name>/`
- `doc/`: yours - knowledge that outlives the task that produced it
- `scripts/` and `doc/` each keep an `index.md`, one bullet per entry: its path relative to the index in inline code, then when an agent would need to read it, never a summary of what it contains. `scripts/data/` and the agenda are not indexed
