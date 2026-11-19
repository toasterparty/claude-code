# Agenda
The agenda lists what is still open in a project, for two readers: a fresh session asked "What's next on the agenda?", and every session closing out its work. A good session removes more items than it adds.

## Items
One bullet per item, highest priority first within its section. An item states in one line what is open and links the document that carries the detail, where one exists: a plan in `inbox/`, a report in `outbox/`, a doc. The detail itself never goes in the agenda: no reports, code snippets, proposals, plans, or data.

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

Never record git state. The user owns staging, committing, and pushing, so an item like "commit and push the staged changes" never appears. A release not yet made is open work. The commits leading up to it are not.

Skip work that is minor and cannot be forgotten, especially when something else already forces it: a check that gates the merge of a PR, a build error the next build reports, a step the running plan already lists. Every such item pushes a real one further down.

Create the agenda when its first item appears.

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
- Check older items against `inbox/`, `outbox/` reports and their open questions, and recent git history. A commit containing an item's change resolves it, and so does a deliverable that finished it.
- Remove an item whose linked document is gone, unless the work it named is still open.
- Archive only your own reports in `outbox/`, as the skill that wrote them directs. A finished plan in `inbox/` loses its item and stays where it is, because `inbox/` is the user's: `/tidy` archives it on their answer.

## What's next
Answer "What's next on the agenda?" with the top item of the top section: what resolving it takes and why it ranks first, then a line each for the next two. Stop there. The user agrees or reorders, then asks next turn to implement it or to walk through its decisions.
