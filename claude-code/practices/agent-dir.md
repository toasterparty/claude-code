# Agent directory
`<repo>/.agent/` holds the agent's working files. Never put them under `<repo>/.claude/`, where every write raises a confirmation prompt that no permission rule clears.

## Layout
`.agent/` is untracked (its `.gitignore` is the single line `*`). That `.gitignore` makes ripgrep, and so the Grep tool, skip every file under `.agent/` without a warning, even when the search path is `.agent/` itself. Search there by giving the Grep tool a `glob` such as `**/*.md`, which overrides the ignore rules, or with `command grep -r`:
- `inbox/`: the user's - plans, raw data, design docs, reference implementations. Read-only to you; search it before researching externally. Create a missing one with `bash practices/agent-dir/ensure-layout.sh --repo <repo>`, since the deny rule that makes it read-only also blocks a `mkdir` that names it
- `outbox/`: yours - deliverables such as samples, PR drafts, and write-ups for review. A deliverable goes to a file only when the user asks for one, and lands here unless they give a path
- `reports/`: yours - one report per skill run that writes one, archived under `reports/_archive/` once nothing in it is open, as `practices/reports.md` describes
- `scripts/`: yours - reusable, argument-driven executables, nothing task-specific. Whatever a script reads or writes goes in `scripts/data/<script-name>/`
- `doc/`: yours - knowledge that outlives the task that produced it, and the agenda that `practices/agenda.md` describes
- `git/`: yours - scratch clones, as `practices/scratch-clones.md` describes. Clone here to read another branch or PR without touching the user's checkout, to read a related repository such as the client of the server you are working on, or to build an artifact from a tree other than the working one, such as comparing an object file built at HEAD against the dirty tree's

`scripts/` and `doc/` each keep an `index.md`, one bullet per entry: its path relative to the index in inline code, then when an agent would need to read it, never a summary of what it contains. `scripts/data/` and the agenda are not indexed. Read `doc/index.md` at the start of a task, and `scripts/index.md` before writing a script or running a multi-step procedure by hand, because both exist so a session reuses what an earlier one learned instead of rediscovering it.

## Project instructions
Project instructions are two files, both loaded at session start: `<repo>/AGENTS.md`, tracked and shared with the repo's other developers, and `<repo>/.agent/AGENTS.md`, untracked and yours alone (project memory). Claude Code loads the first natively and a hook loads the second. A root `CLAUDE.md`, which other developers' repos may carry, still loads beside them. Create neither file unasked, since the user decides when a repo gets instructions. When the user asks for agent instructions in a repo, put them in one of these two files, never in a new `CLAUDE.md`.
