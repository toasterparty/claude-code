---
name: next
description: Run a session off this project's agenda by intent - unblock it with the user's decisions and tasks, review and groom it with the user, work it autonomously, or orchestrate a larger objective through subagents - clearing out items found already resolved on the way.
argument-hint: "[unblock|review|autonomous|orchestrate] [section or objective]"
disable-model-invocation: true
---

# Next

Expect an agenda that has fallen behind the repo, with items a commit already resolved or whose linked document is gone. Clearing those out on the way is part of the job, not a sign that something went wrong.

Read `practices/agenda.md` and `.agent/doc/index.md` before anything else. The agenda practice defines the item kinds, the tags, the sticky order, and the evidence that resolves an item, and every step below relies on it. Where the project has no agenda, or it holds no items, say so and stop.

## 1. Intent
The intent is what the session is for. An intent given with the invocation, in any wording, is used as-is. Otherwise ask it first with `AskUserQuestion`, offering these in this order:
- **Unblock** - the user has time to make the decisions and carry out the tasks the agenda waits on. Step 3
- **Review** - the user wants to hear what is open, clear out stale items, reorder, and pick what this session works on. Step 4
- **Autonomous** - the user steps away while the session works the agenda from the top, as much as one session holds. Step 5
- **Orchestrate** - after answering one batch of pre-flight questions, the user steps away while the session drives an objective no single session could finish, such as a large technical hurdle or a wide verification gap, delegating all of the work to subagents. Step 6. Offer it only where the session model is Opus or above, because the orchestrator must be able to judge and correct every subagent below it. Asked for by invocation on a lower model, run Autonomous instead and say why in the close

Mark one intent `(Recommended)` and list it first only where the agenda, read by its tags alone, makes it a clear winner, giving the reason in its description.

Any other text given with the invocation names the section to work in, or for Orchestrate the objective.

In Unblock and Review the user is on hand: ask wherever an answer would settle something faster or more surely than you could alone, after reading `practices/decisions.md`, which sends each decision to `/consult` or a direct question. The user is away in Autonomous after the intent question, and in Orchestrate after the pre-flight batch step 6 describes: follow `When the user is away` in `practices/decisions.md`.

Once the intent is Autonomous or Orchestrate, start the report step 9 describes, before the walk's first edit.

## 2. Walk the agenda
Walk sections top to bottom and items top to bottom within each, opening a split-out section's own file when the walk reaches it, and classify each item as `Reconciling` in `practices/agenda.md` describes: resolved, unclear, blocked, or open. Ask about an unclear item where the user is on hand, and otherwise leave it and flag it in the close. Autonomous and Orchestrate skip a blocked item, along with the items `blocked by` it, except that a `User Decision` item's `Research:` sub-bullet is open work: answer it in the item's linked doc, or a new one under `doc/`, and replace the sub-bullet with a link to the findings, leaving the decision to the user.

How far the walk goes depends on the intent. Unblock and Review walk the whole agenda, because every item is a candidate. Autonomous walks until the first open item whose model tag matches the session's model, an untagged item counting as `Opus`, and that item is the pick. A walk that reaches the end without one picks the first open item it passed, because cheaper work left for a cheaper session saves tokens but no session should idle on it. Each later pick in the same run extends the walk the same way. Orchestrate walks the items its objective covers, and none where the objective is new work no item names. A section given with the invocation limits every walk to that section. A full reconciliation against `inbox/` and the reports belongs to `/tidy`, not here.

Never make a user's decision on your own lean to unblock an item, even where you would recommend an answer. Work another thread instead: there are usually several, and progress there costs the user nothing to review. Where only part of an item depends on the open decision, carry out the part that does not, and narrow the item to what remains. Where the decision has no item of its own yet, add one tagged `User Decision` and tag the item `blocked by` it.

Never move an item or section without the user's agreement, because the order decides what the next session works on. Skipping an item is not reordering. Where the user is away, propose a move in the close instead.

## 3. Unblock
Hand every non-trivial decision in the walk to one `/consult`, whether it is a `User Decision` item or a choice an earlier run made without asking that an item or its linked report puts up for review, its subject naming each item's ID and linked document, so the decisions share one round of research. Leave out the review items shared by agent-owned decisions or by an autonomous `/refine`'s taste proposals: the user vetoes or takes them up from their report when they choose to, and nothing waits on them. Then ask the remaining decision items and every unclear item directly, in rounds of up to four questions, in agenda order unless a decision blocks more work than the ones above it. Each direct question gives just enough context for a user who may not remember the item, drawn from its linked document, and each option states what it leads to. Mark one `(Recommended)` only where it is strongly advisable. Record each answer, from the consult or a direct question, in the doc it governs, never an `inbox/` asset, or where none exists as a sub-bullet on the item it unblocks, then narrow the item, or remove it with `resolve.sh`, which clears the `blocked by` tags it releases.

Then walk the `User Task` items, one at a time in agenda order. Give the exact steps: commands to run, where to look, and the result that counts as done. Verify each task the user reports done against evidence you can check yourself where one exists, such as a CI run, a file, or a log, then remove the item. A task the user cannot do now stays, with anything learned added as a sub-bullet.

Then close as step 9 directs, adding to its counts the items this session unblocked, since the next Autonomous run can take them.

## 4. Review
Brief in chat, by section in agenda order: a line each for the open items worth doing next, with why the top one ranks first, then how many items the walk removed as resolved, and every move you would propose.

Then ask in one `AskUserQuestion` batch, adding calls only if more than four questions remain:
- The pick: the top open item, the next two as alternatives, and `None` to stop after the cleanup. Another item or a reorder comes through `Other`
- Each unclear item, and each stale section whose date has fallen well behind its neighbors', each option stating what happens to it
- Each proposed move of an item or section

Apply the answers before any other work: remove what the user settles with `resolve.sh`, and make the moves they agree to. Then carry out the pick with the user on hand, as step 7 routes it, or stop where they picked none.

## 5. Autonomous
Carry out the pick as step 7 routes it, then take the next pick while the session has room, as step 8 sizes it.

## 6. Orchestrate
Read `practices/orchestration.md` and orchestrate as it describes. The agenda adds these:
- Take the objective from the invocation. Without one, start from the topmost section with open items, and take as the objective the largest body of related work that leads from its top item: the items it unblocks, and those sharing its code or its verification gap. Name the objective in the report
- Ask one pre-flight batch before the first delegation, while the user is still at the keyboard: read the items the objective covers and their linked documents, list every decision the work will plainly need that nothing written settles, and put them to the user as `practices/decisions.md` sorts them, non-trivial ones through one `/consult`. Where the list is empty, ask nothing. Ask nothing after the batch, because the user leaves once it is answered
- Each subagent's result lists the agenda items it would add and remove, as `practices/agenda.md` describes for a subagent, and you carry them out
- Each call the orchestrator makes for a subagent goes under the report's `Decided without asking`, and a question the practice lets block becomes a `User Decision` item. Expect few blocks: an agenda that needed many answers would have recommended Unblock
- A `/refine` subagent runs in `autonomous-fix` mode, and returns its raised items for you to decide as `practices/orchestration.md` describes
- The close is step 9's

## 7. Carry out a pick
Route by what the item asks for:
- **A plan not yet executed** - follow the execution rules in `practices/plans.md`
- **Code not yet refined** - invoke `/refine` through the `Skill` tool, passing the item's scope and the mode, `guided-fix` where the user is on hand and `autonomous-fix` otherwise, so it asks neither. Bugs with one clear fix are approved in advance for every `/next` run
- **A plan or design not yet consulted** - invoke `/consult` with the item's subject, only where the user is on hand. Otherwise the item is blocked
- **Anything else** - do the work directly

A skill invoked this way in this session updates the agenda for its own work. Do not repeat its updates.

## 8. Size the run
Decide how much one session should take on, weighing the model, effort level, the risk of the work, the context already used, and token cost. After each item, take the next pick only where it fits comfortably in what remains. Stop at an item boundary rather than leave two items half done, because the user reviews the whole run as one unstaged diff.

An item too large for one session gets a slice that leaves the tree working. Narrow the item to the work that remains.

## 9. Close
Update the agenda as the practice directs, for each item resolved, narrowed, or added. That includes the item it calls for once code is feature-complete and not yet refined.

### Report
Autonomous and Orchestrate runs write a report under `practices/reports.md`, with `--skill next` and the intent as `mode`, because the user reviews a run they did not watch after its chat is gone. A run that handed no work to a subagent (Explore does not count), decided nothing without asking, and left nothing untested writes `## Done` alone and archives its report at the close. Deleting it instead would free its sequence letter for the next run, and the reports would no longer list in run order.

A decision made without asking is a choice the work forced that no plan, doc, or answer settled, made in the spirit of the item: never a decision an item tags `User Decision`. Close the run as `Closing a run` in `practices/reports.md` describes. The items it opens are one review item shared by every agent-owned decision, as `practices/agenda.md` describes, one per group of other decisions the user would confirm or veto together, tagged `User Decision`, and one per group of untested work that would be exercised together, tagged `User Task` where only the user can exercise it. The body after the front matter is:

```
# Next <objective, section, or agenda>

## Done
- #<id> <what landed, and the validation that passed>

## Decided without asking
1. **#<id> <decision>** - <what was chosen, why, and the alternative given up>

## Untested
- #<id> <what no check exercised, and what would exercise it>
```

### Chat
Report in chat:
- What was done and where you deviated
- The agenda in counts, as `Chat reports` in `practices/agenda.md` describes: items removed, added, and left unclear, and the decisions and tasks waiting on the user
- Any proposed reorder
- The intent and subject best suited to the next `/next` run

Keep it a summary. The user often skips it, so anything a later session needs must already be in the diff, the agenda, or a report.
