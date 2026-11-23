# Agenda
The agenda lists what is still open in a project, for two readers: a fresh session asked "What's next on the agenda?", and every session closing out its work. A good session removes more items than it adds.

## Items
One bullet per item, highest priority first within its section. An item opens with its ID and a one-line headline stating what is open, followed by its tags, and links the document that carries the detail, where one exists: a plan in `inbox/`, a report in `reports/`, a doc. Indented sub-bullets under the headline may carry short context a later session would otherwise rediscover: a finding, a constraint, an approach already ruled out. Anything longer goes in the linked doc, and the agenda never holds reports, code snippets, proposals, plans, or data. The headline stays one line so the agenda still reads at a glance.

```
- #12 Decide whether the pause screen draws premultiplied like the HUD (`hud-blending.md`) `User Decision`
- #14 Port the premultiplied draw path to the pause screen `blocked by #12`
    - The inventory screen shares its draw call, so it changes too
- #15 Recheck the reticles in game on a rebuilt ISO `User Task` `open @8464ba4`
```

A document with several open points gets one item per point, each linking it, so the user can rank an urgent question above unrelated work. Group points that would be resolved together into one item.

Open work the agenda tracks includes:
- design not yet created
- functionality not yet implemented
- changes not yet reviewed, under the rule below
- decisions not yet made
- verification or validation not yet done
- tasks outside the project's scope or beyond an agent's capabilities, for the user to carry out
- plans not yet executed
- releases not yet made
- data not yet gathered
- feature-complete code not yet `/refine`d
- incomplete plans not yet `/consult`ed

Most code should pass through `/refine` at least once after its last substantial change. A session that finishes a feature, a rewrite, or a large fix adds a refine item naming that scope, or widens a refine item already open, since one item per module reads better than a trail of small ones. A small fix gets none.

Never record git state. The user owns staging, committing, and pushing, so an item like "commit and push the staged changes" never appears. A release not yet made is open work. The commits leading up to it are not.

Skip work that is minor and cannot be forgotten, especially when something else already forces it: a check that gates the merge of a PR, a build error the next build reports, a step the running plan already lists. Every such item pushes a real one further down.

Create the agenda when its first item appears.

## IDs
Every item carries a permanent ID, `#N`, so a dependency, a report, a log line, or the user ("do 14") can name it. Take new IDs from `bash practices/agenda/next-id.sh --repo <repo>`, adding `--count <n>` for several at once, and never by reading the agenda and adding one, because two sessions in one repo would then hand out the same ID. The script prints one ID per line and keeps its counter in `.agent/doc/agenda-id`.

An ID is never reused or renumbered, because an old reference would then point at the wrong item. An item narrowed to its remaining work keeps its ID. An item split in two keeps its ID on the part that stays and takes a new ID for the part split off.

## Tags
A tag records a fact a session confirmed, so the next session does not rediscover it. Write each tag in inline code after the headline, and use only these:
- `User Task` - only the user can carry it out: a check on their hardware, a step needing their credentials, an action on a PR, a task outside the project.
- `User Decision` - a decision only the user can make. No session makes it on its own lean, even where it would recommend an answer.
- `blocked by #N` - the item cannot start until item #N resolves, as in `blocked by #12, #13`. An item that waits on a decision is blocked by that decision's own `User Decision` item. A blocker outside the agenda, such as an upstream release, is written in words: `blocked: c-wspp lacks permessage-deflate`.
- `open @<commit>` - a session checked the item against the repo at that commit, the short hash of `HEAD`, and found it still open. A later session trusts it and skips reconciling the item unless a commit since then touches what the item names. Restamp it on every re-check, and drop it when an edit to the item changes what done means.

A dependency is written on the blocked item only, so the agenda holds each dependency once. A session that resolves an item searches the agenda for its ID, in split-out section files too, and clears or narrows each `blocked by` that named it in the same edit.

## Sections
Items against the same task, branch, or topic share a `##` section, named for it, so the reader can take or skip the group whole. An item that fits no group stays in a `## General` section rather than loose above the first heading.

Each section heading ends with the date of the last session that added, resolved, or edited one of its items: `## Hook refactor - 2026-11-19`. Bump it on every such touch, and never for a reorder alone. The date tells `/tidy` which sections have gone quiet.

A section that no longer reads at a glance, roughly more than seven items, moves to its own file: `.agent/doc/agenda/<section>.md`, with the agenda itself moving to `.agent/doc/agenda/index.md` on the first extraction. The section keeps its heading and date in the index, with its top item and a link to the file below them, and the file holds the full list under the same rules. Fold the file back into the index once it shrinks to a few items.

## Order
The user's order is sticky, both of sections and of items within one. Insert a new item or section where its priority puts it, but never move an existing one without the user's agreement. Propose the move instead, because the order decides what the next session works on.

## Review items
Add a review item only for a change that is controversial, or whose details the user contested or showed interest in. Routine changes get none, since the unstaged diff already lists them. The item resolves on evidence that the user reviewed the change: a commit containing it, or the user settling it in a session. A `/code-review` report is not that evidence.

## Updating
- Remove what the session resolved and add what it left open. A session that changed nothing open leaves the agenda alone.
- Check older items against `inbox/`, `reports/`, and recent git history. A commit containing an item's change resolves it, and so does a deliverable that finished it.
- Remove an item whose linked document is gone, unless the work it named is still open.
- A removal that leaves a linked report with no open ID archives that report, as `practices/reports.md` describes. A finished plan in `inbox/` loses its item and stays where it is, because `inbox/` is the user's: `/tidy` archives it on their answer.

Every removal appends one line to `.agent/doc/agenda-log.md`, created with its first line: the date, the ID, `resolved` or `dropped`, the headline, and the evidence or reason, as in `- 2026-11-20 #14 resolved: Port the premultiplied draw path to the pause screen. Landed in a1b2c3d`. The log is append-only and no session reads it by default. It lets the user trace an item that vanished, and it keeps retired IDs on file.

## What's next
Answer "What's next on the agenda?" with the top item of the top section: what resolving it takes and why it ranks first, then a line each for the next two. Stop there. The user agrees or reorders, then asks next turn to implement it or to walk through its decisions. `/next` is the user's way to work the agenda in one run.

Answer "What's on me?" with every `User Task` and `User Decision` item, by section in agenda order, since they stay in their threads rather than in a section of their own.
