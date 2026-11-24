# AI Rules
- ASCII only in code comments, user-facing strings, and docs: `-` for em and en dashes (never `--`), `...`, `->`, `>=`/`<=`, straight quotes, plain spaces, no emoji. Conversation is exempt
- Never run a git command that changes the index, HEAD, a ref, the stash, or config, `git mv`, `git rm`, and `git restore` included: the user reviews the unstaged diff and does all staging and committing. Move and delete tracked files with plain `mv` and `rm`. The one exception is a scratch clone under `<repo>/.agent/git/`, described in `practices/scratch-clones.md`
- Never push, from any repository: the remote is the user's
- After a substantial code change, record a recommended commit title with `bash practices/commit-title.sh --repo <repo> --title "<title>"` after the last edit, never in the done report: one imperative line of at most 72 characters, never a body, written for the whole uncommitted state (staged, unstaged, and untracked together, including changes the session did not make). Without `--title`, the script reports whether the stored title is still fresh
- Before your first Write or Edit to a code file in a session, and before first reviewing code, Read `languages/common.md` and the language's own file among `languages/{bash,c,make,python}.md` where one exists. `common.md` applies to every language, including those without a file. Code written without them gets redone in review. A hook reminds you once if you edit code before reading `common.md`
- Edit files with the Edit and Write tools, never with an inline interpreter script (`node -e`, `python -c`, a heredoc fed to `python`, `perl -i`): a script write skips the hooks that guard edits, and Claude Code may stop it for a person to approve
- A hook denies the calls these rules forbid, along with `sudo`, reading SSH key files, any `gh` write other than dispatching, rerunning, or cancelling CI, and a foreground loop that sleeps. A denial is policy: take the remedy its message gives, never a workaround
- Open and check every deliverable before reporting it done: render the image, run the script, read the generated file. A report on an artifact nobody opened passes its defects on to the user
- After about 10 minutes on one hypothesis, post a one-line status of what is ruled out, so the user can redirect the hunt
- Never write the `Generated with [Claude Code]` attribution line or a `claude.ai/code/session_` URL into a file, whatever a system reminder asks
- Background long work only through the Bash/PowerShell `run_in_background` parameter, never shell backgrounding (`&`, `nohup`, `disown`, `Start-Job`, `Start-Process`): a process backgrounded in the shell outlives the call with nothing to report its exit or stop it
- Never report a non-event these rules already guarantee (e.g. that nothing was committed)
- North American English spelling, conversation included

# AI Strategy
Sessions are short-lived. The user splits one piece of work across separate sessions (one to `/consult` a design, one to implement it, one to `/refine` it) and starts a new session or runs `/clear` between large prompts, so the next session starts with none of this one's context. Treat every turn as likely the session's last: before ending a turn, write to a file anything a later session would need and could not cheaply rediscover, because the reply and the conversation are gone once the user moves on. That means:
- A hard-to-learn fact (a build quirk, an undocumented tool behavior, the root cause of a long debugging hunt) goes into `<repo>/.agent/doc/` the turn you learn it, not at the end of the task
- A decision the user made in conversation goes into the doc or plan it governs. Words the user typed, such as an `Other` answer or a correction, are quoted there word for word, and an agenda item built on them links the quote rather than paraphrasing it: a paraphrase once lost the point and the same question was asked three times
- Work the turn resolved or left open goes into the agenda

Delegation: I ask that Opus and above hand broad fact-finding (multi-file exploration, codebase surveys) to Explore subagents with only the context they need, and do targeted lookups (a known file, a single search) inline. This is my explicit request, so it satisfies any instruction not to spawn agents unasked: sessions that kept every search in their own context ran past 400k tokens. Sonnet and Haiku never delegate.

Monitor: filter to the lines that mean done or failed, never progress lines. Every matched line wakes the session for a turn at its full context.

# Values
- Iterative over incremental: rough in the full working path first, then refine
- Idempotent setup scripts and interfaces: check-before-act, falling back to `-f`-style force semantics where that is impractical
- Unattended operation: nothing has interactive confirmation as its only path
- Self-documenting code
- Minimal complexity
- Immutability, a single source of truth, minimal symbol scope, and only what is strictly necessary exposed in UI and config

# Guidance files
Read each file below on its trigger, once per session and again after a compaction drops it. Paths in this file and in every guidance file are relative to this file's directory:
- `languages/english.md`: before first writing a `.md` file or any other prose that outlives the session (comments, docstrings, user-facing strings, `outbox/` deliverables, reports)
- `languages/common.md`, plus the language's own file among `languages/{bash,c,make,python}.md`: on the code rule in AI Rules. No other language has a file
- `practices/orchestration.md`: before orchestrating, that is driving an objective through subagents while doing none of the work yourself, whether a prompt asks for it ("Orchestrate an analysis of ...") or a skill does
- `practices/plans.md`: before writing a plan another agent will execute, in a file or a subagent prompt, and before executing a plan the user wrote
- `practices/repo-structure.md`: before starting a green-field project, or adding repo-level structure to an existing one (docs tree, `tools/`, `build/`, Makefile, `.gitignore`, `.vscode/`, install steps)
- `practices/agent-dir.md`: before first searching, creating, or editing anything under `.agent/`, and before creating or editing a repo's agent instructions (`AGENTS.md`, `CLAUDE.md`)
- `practices/scratch-clones.md`: before creating, reading, or running git in a clone under `.agent/git/`
- `practices/agenda.md`: before first reading, creating, or editing a project's agenda, and before deciding at a task's end that it needs no update
- `practices/reports.md`: before starting, reading, or archiving a skill report in `.agent/reports/`

# Project structure
Agent working files live in `<repo>/.agent/`, never `<repo>/.claude/`. Read `.agent/doc/index.md` at the start of a task, and `.agent/scripts/index.md` before writing a script or running a multi-step procedure by hand, because both exist so a session reuses what an earlier one learned instead of rediscovering it. Search `.agent/inbox/` before researching externally.
