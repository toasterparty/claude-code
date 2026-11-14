# Agenda
The agenda lists what is still open in a project, for two readers: a fresh session asked "What's next on the agenda?", and every session closing out its work. A good session removes more items than it adds.

## Items
One bullet per item, highest priority first. An item states in one line what is open and links the document that carries the detail, where one exists: a plan in `inbox/`, a report in `outbox/`, a doc. The detail itself never goes in the agenda: no reports, code snippets, proposals, plans, or data.

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

Create the agenda when its first item appears. Once one file no longer reads at a glance, split it by area into `.agent/doc/agenda/<area>.md`, with `agenda/index.md` holding the top items across areas plus one line per area file saying when to read it.

## Order
The user's order is sticky. Insert a new item where its priority puts it, but never move an existing item without the user's agreement. Propose the move instead, because the order decides what the next session works on.

## Review items
Add a review item only for a change that is controversial, or whose details the user contested or showed interest in. Routine changes get none, since the unstaged diff already lists them. The item resolves on evidence that the user reviewed the change: a commit containing it, or the user settling it in a session. A `/code-review` report is not that evidence.

## Updating
- Remove what the session resolved and add what it left open. A session that changed nothing open leaves the agenda alone.
- Check older items against `inbox/`, `outbox/` reports and their open questions, and recent git history. A commit containing an item's change resolves it, and so does a deliverable that finished it.
- Remove an item whose linked document is gone, unless the work it named is still open.
- Archive only your own reports in `outbox/`, as the skill that wrote them directs. A finished plan in `inbox/` loses its item and stays where it is, because `inbox/` is the user's: `/tidy-claude` archives it on their answer.

## What's next
Answer "What's next on the agenda?" with the top item: what resolving it takes and why it ranks first, then a line each for the next two. Stop there. The user agrees or reorders, then asks next turn to implement it or to walk through its decisions.
