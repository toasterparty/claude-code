# Migrate legacy layouts
Older layouts kept agent files in `<repo>/.claude/{inbox,outbox,scripts,doc}/`, in `plans/`, `reference/`, and `agent/`, and project memory in a `CLAUDE.md` at the repo root, in `.agent/`, or in `.claude/`. These are the legacy locations `/tidy` may touch besides `.agent/`. Leave everything else in `<repo>/.claude/` alone, and remove a legacy dir from `.claude/` only once its contents are safely moved. Moving a whole file out of a legacy location is the one change allowed against user content.

Move:
- `.claude/{inbox,outbox,scripts,doc}/*` -> the matching dir under `.agent/`, subdirectories intact
- `.agent/CLAUDE.md`, `.claude/CLAUDE.md`, and an untracked root `CLAUDE.md` -> `.agent/AGENTS.md`, appending to it where it already exists
- a tracked root `CLAUDE.md` -> `AGENTS.md`, only on the user's answer in step 3, appending to a tracked `AGENTS.md` where one exists. Move it with plain `mv`, leaving the rename for the user to stage
- `scripts/data/tidy-claude/` -> `scripts/data/tidy/`, merging into it where it exists
- `reference/*` -> `inbox/`
- `plans/*` -> `inbox/`, and its `archive/` or `_archive/` subdirs -> `inbox/_archive/`
- `agent/` scripts -> `scripts/` if worth reusing, otherwise delete
- `agent/` notes that still teach something -> `doc/`
- skill reports written before `practices/reports.md`, such as `outbox/refine/`, `outbox/consult/`, and `refine-*` or `review-*` files, archived or not -> `reports/_archive/`, contents unchanged, each name prefixed with its old subdir under `outbox/` (minus any `_archive/` level) so names cannot collide, as in `outbox/refine/_archive/202611021811-b357e5f.md` -> `reports/_archive/refine-202611021811-b357e5f.md`. Give each review item or open question still open in them an agenda item tagged `User Decision`, unless one already covers it: an item not marked `[resolved: ...]`, `[dropped: ...]`, or `[moved: ...]`, whose code or question still stands. Repoint every agenda link to a moved file
- other agent-authored reports in any legacy dir -> `outbox/_archive/`

Move a legacy dir bound for `inbox/` whole, as in `mv .claude/inbox .agent/`, which replaces the empty `inbox/` step 1 created. The deny rule on `inbox/` blocks any command that names it as a target, so a file move into it, or a second source once it holds files, is denied: leave that source in place and flag it in the report.

A tracked root `CLAUDE.md` always goes into step 3's batch as ambiguous: rename it only in a repo the user owns, and only the user can say whether they own it, since a work repo's remote names an org rather than an owner. Other developers' repos keep their `CLAUDE.md`.

In step 7, once an untracked root `CLAUDE.md` has moved, delete its line from `.git/info/exclude`, which an older layout added to keep it out of git.
