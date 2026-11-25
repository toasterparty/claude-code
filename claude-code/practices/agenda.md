# Agenda
The agenda lists what is still open in a project, for two readers: a fresh session asked "What's next on the agenda?", and every session closing out its work. A good session removes more items than it adds.

The agenda lives at `<repo>/.agent/doc/agenda.md`, or `<repo>/.agent/doc/agenda/index.md` once split. Read it when the user asks about it or what's next. Before reporting a task done, update it with what the session resolved and left open, because the next prompt usually lands in a fresh session that knows only what the agenda says. A hook reminds you of this once per session, after your first edit outside `.agent/`. Only the top-level session edits it, so parallel agents never collide in one file. A subagent still takes the IDs of the items it would add from `next-id.sh` and writes them into its report's `opened`, where it writes a report, but never edits the agenda: its result gives the full line of each item to add and the ID and evidence of each item to remove, and the parent session inserts and removes them.

## Items
One bullet per item, highest priority first within its section. An item opens with its ID and a one-line headline stating what is open, followed by its tags, and links the document that carries the detail, where one exists: a report in `reports/`, a doc. Never an `inbox/` asset, under the rule below. Indented sub-bullets under the headline may carry short context a later session would otherwise rediscover: a finding, a constraint, an approach already ruled out. Anything longer goes in the linked doc, and the agenda never holds reports, code snippets, proposals, plans, or data. The headline stays one line so the agenda still reads at a glance.

```
- #12 Decide whether the pause screen draws premultiplied like the HUD (`hud-blending.md`) `User Decision`
- #14 Port the premultiplied draw path to the pause screen `blocked by #12`
    - The inventory screen shares its draw call, so it changes too
- #15 Recheck the reticles in game on a rebuilt ISO `User Task` `open @8464ba4`
```

A document with several open points gets one item per point, each linking it, so the user can rank an urgent question above unrelated work. Group points that would be resolved together into one item.

## Inbox independence
`inbox/` is the user's, and they may delete anything in it at any time, so no item names, links, or depends on an `inbox/` asset. Triaging one means carrying every action it implies into items that stand alone: the headline and sub-bullets state the work, and where the detail runs longer, a copy or distillation under `doc/` carries it, linked as any doc is. A plan not yet executed is copied whole, since the executing session must read all of it. Once its actions are on the agenda or done, the asset is safe to delete. Never wait on the user to delete it, and never delete it yourself.

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
Every item carries a permanent ID, `#N`, so a dependency, a report, a log line, or the user ("do 14") can name it. Take new IDs from `bash practices/agenda/next-id.sh --repo <repo>`, adding `--count <n>` for several at once, and never by reading the agenda and adding one, because two sessions in one repo would then hand out the same ID. The script prints one ID per line and keeps its counter in `.agent/doc/agenda-id`. An ID is never written anywhere, the log and a report included, before `next-id.sh` has printed it, because the number you expect may go to another session first: one run wrote `#61` into the log, and the script then handed it 62.

The script counts an ID as in use where it opens an item, sits in a `blocked by` tag, or names a log line. Write a number from outside the agenda, such as a pull request, without the `#`, as in `PR 188`, so no reader takes it for an item.

An ID is never reused or renumbered, because an old reference would then point at the wrong item. An item narrowed to its remaining work keeps its ID. An item split in two keeps its ID on the part that stays and takes a new ID for the part split off.

## Tags
A tag records a fact a session confirmed, so the next session does not rediscover it. Write each tag in inline code after the headline, and use only these:
- `User Task` - only the user can carry it out: a check on their hardware, a step needing their credentials, an action on a PR, a task outside the project.
- `User Decision` - a decision only the user can make. No session makes it on its own lean, even where it would recommend an answer.
- `blocked by #N` - the item cannot start until item #N resolves, as in `blocked by #12, #13`. An item that waits on a decision is blocked by that decision's own `User Decision` item. A blocker outside the agenda, such as an upstream release, is written in words: `blocked: c-wspp lacks permessage-deflate`.
- `open @<commit>` - a session checked the item against the repo at that commit, the short hash of `HEAD`, and found it still open, as `Reconciling` describes. Drop it when an edit to the item changes what done means.
- `Fable`, `Opus`, or `Sonnet` - the cheapest model trusted with the work, ranked Fable above Opus above Sonnet. `Sonnet` fits an item whose linked plan leaves no judgment open: exact files, steps, and verification. An untagged item counts as `Opus`. A session tags only below its own model, because judging whether a model suffices takes a stronger one: Fable may tag `Opus` or `Sonnet`, Opus may tag `Sonnet`, and Sonnet tags nothing. `Fable` goes on an item only where the user proposed it or agreed to it in conversation. A session skips an item tagged above its own model, and `/next` works the items tagged for its own model first.

A dependency is written on the blocked item only, so the agenda holds each dependency once. Removing an item with `resolve.sh`, under `Updating`, clears its ID from every `blocked by` tag, in split-out section files too.

## Sections
Items against the same task, branch, or topic share a `##` section, named for it, so the reader can take or skip the group whole. An item that fits no group stays in a `## General` section rather than loose above the first heading.

Each section heading ends with the date of the last session that added, resolved, or edited one of its items: `## Hook refactor - 2026-11-19`. Bump it on every such touch, and never for a reorder alone. The date tells `/tidy` which sections have gone quiet.

A section that no longer reads at a glance, roughly more than seven items, moves to its own file: `.agent/doc/agenda/<section>.md`, with the agenda itself moving to `.agent/doc/agenda/index.md` on the first extraction. The section keeps its heading and date in the index, with its top item and a link to the file below them, and the file holds the full list under the same rules. Fold the file back into the index once it shrinks to a few items.

## Order
The user's order is sticky, both of sections and of items within one. Insert a new item or section where its priority puts it, but never move an existing one without the user's agreement. Propose the move instead, because the order decides what the next session works on.

## Review items
Add a review item only for a change that is controversial, or whose details the user contested or showed interest in. Routine changes get none, since the unstaged diff already lists them. The item resolves on evidence that the user reviewed the change: a commit containing it, or the user settling it in a session. A `/code-review` report is not that evidence.

A run that made agent-owned decisions, as `practices/decisions.md` defines them, adds one review item for all of them, linking the report that lists them, as in `` - #31 Review the agent-owned decisions of the controls run (`20261124a-next-controls.md`) ``. It carries no `User Decision` tag, so nothing waits on it, and it resolves like any review item.

An autonomous `/refine` adds one such item for the taste-only proposals it raised, listed in its report under `Taste proposals`. It resolves when the user settles them in a session, or when a guided `/refine` over the same scope takes them up as its own raised items.

## Updating
- Remove what the session resolved and add what it left open. A session that changed nothing open leaves the agenda alone.
- Check older items against `inbox/`, `reports/`, and recent git history, as `Reconciling` describes.
- A finished plan in `inbox/` stays where it is when its item goes, because `inbox/` is the user's: `/tidy` archives it on their answer.

Remove an item with the script, never by editing it out:

```
bash practices/agenda/resolve.sh --repo <repo> --id <n> --status resolved|dropped --evidence "<evidence or reason>"
```

A removal has five parts, and runs that did them by hand skipped some. Under the lock `next-id.sh` takes, the script deletes the item and its sub-bullets, appends its line to `.agent/doc/agenda-log.md`, clears its ID from every `blocked by` tag, dates its section heading today, and archives each report in `reports/` whose `opened` IDs are now all logged, as `practices/reports.md` describes. It prints one line per action. A split-out section's top item and its copy in the index count as one item, and the script replaces the copy with the section's new top item, or removes it once the section has none. An ID that opens no item, or more than one in any other arrangement, is an error that changes nothing. Narrowing or adding an item stays an edit.

The log line holds the date, the ID, the status, the headline without its tags, and the evidence, as in `- 2026-11-20 #14 resolved: Port the premultiplied draw path to the pause screen. Landed in a1b2c3d`. Name a report in the evidence by its file name alone, never by path, because the report moves to `_archive/` and the path then points nowhere. The script cuts a report path in the headline to its file name. The log is append-only and no session reads it by default. It lets the user trace an item that vanished, and it keeps retired IDs on file.

## Reconciling
Reconciling checks items against the repo, because an agenda falls behind it: a commit resolves an item, or its linked document goes. Classify each item checked:
- **Resolved** - evidence proves it done: a commit containing its change, the described behavior or file present in the repo, a deliverable that finished it, a plan whose boxes are all checked and whose changes landed, a decision recorded in a doc or plan, or a linked document gone with the work it named finished. Remove it with `resolve.sh`
- **Unclear** - only partial or circumstantial evidence that it is done. Never remove one on a guess. The skill doing the walk says whether to ask the user about it or leave it in place
- **Blocked** - it needs something only the user can give: a decision not yet made, a task outside the agent's reach, validation that needs their hardware or credentials, or a `/consult` while the user is away. Or it waits on another item still open, or carries a model tag above the session's own model, as `Tags` ranks them
- **Open** - doable now

Trust the tags before re-deriving anything. An item tagged `User Task` or `User Decision`, or `blocked by` an item still on the agenda, is blocked without a check. A `blocked by` naming an ID no longer on the agenda is stale: clear it and classify the item afresh. An item stamped `open @<commit>` is not resolved, unless a commit since that one touches what it names.

Record what the check confirms, so the next walk can skip it: stamp `open @<HEAD>` on each item checked and found still open, restamping one already stamped, and add the tag for each blocker found that the item did not yet name. An item classified from its tags or an existing stamp alone was not checked, so its stamp stays as it was, because a restamp claims a check that never ran.

## What's next
Answer "What's next on the agenda?" with the top item of the top section: what resolving it takes and why it ranks first, then a line each for the next two. Stop there. The user agrees or reorders, then asks next turn to implement it or to walk through its decisions. `/next` is the user's way to work the agenda in one run.

Answer "What's on me?" with every `User Task` and `User Decision` item, by section in agenda order, since they stay in their threads rather than in a section of their own.
