---
name: next
description: Pick the next work off this project's agenda and carry it out, guided or autonomous, clearing out items found already resolved on the way.
argument-hint: "[guided|autonomous] [section]"
disable-model-invocation: true
---

# Next

Work the agenda from the top: find the highest item that is still open and doable, carry it out, and repeat while the session has room. Expect an agenda that has fallen behind the repo, with items a commit already resolved or whose linked document is gone. Clearing those out on the way is part of the job, not a sign that something went wrong.

Read `practices/agenda.md` and `.agent/doc/index.md` before anything else. The agenda practice defines the item kinds, the sticky order, and the evidence that resolves an item, and every step below relies on it. Where the project has no agenda, or it holds no items, say so and stop.

## 1. Mode
Mode is whether the run may stop for the user. A mode given with the invocation (`guided` or `autonomous`, in any wording) is used as-is. Otherwise ask it first with `AskUserQuestion`, offering `Guided` (the user stays on hand to answer questions) and `Autonomous` (the user steps away, and the run ends in a report and agenda updates).

In autonomous mode, ask nothing after the mode question, because the user is not there to answer and a pending question stalls the whole run.

Any other text given with the invocation names a section or thread to work in. Walk only that section in step 2.

## 2. Walk the agenda
Walk sections top to bottom and items top to bottom within each, opening a split-out section's own file when the walk reaches it. Classify each item until you reach the pick, which is the first item you can carry out:
- **Resolved** - the evidence the agenda practice names proves it done: a commit containing its change, the described behavior or file present in the repo, a linked document gone with its work finished. Remove it, logging the removal and clearing the `blocked by` tags that named it
- **Unclear** - only partial or circumstantial evidence that it is done. In guided mode, ask in step 3. In autonomous mode, leave it and flag it in the report. Never remove an item on a guess
- **Blocked** - it needs something only the user can give: a decision not yet made, a task outside the agent's reach, validation that needs their hardware or credentials, or a `/consult` in autonomous mode. Or it waits on another item still open. In guided mode, ask its blocking decision in step 3. In autonomous mode, skip it, and skip the items `blocked by` it
- **Open** - doable now. This is the pick

Trust the tags before re-deriving anything. An item tagged `User Task` or `User Decision`, or `blocked by` an item still on the agenda, is blocked without a check. A `blocked by` naming an ID no longer on the agenda is stale: clear it and classify the item afresh. An item stamped `open @<commit>` is not resolved, unless a commit since that one touches what it names. Record what the check confirms, so the next walk can skip it: stamp `open @<HEAD>` on each item checked and found still open, and add the tag for each blocker found that the item did not yet name.

Only items above the pick get this check, because a full reconciliation belongs to `/tidy`. Each later pick in the same run extends the check down to it.

Never make a user's decision on your own lean to unblock an item, even where you would recommend an answer. Work another thread instead: there are usually several, and progress there costs the user nothing to review. Where only part of an item depends on the open decision, carry out the part that does not, and narrow the item to what remains. Where the decision has no item of its own yet, add one tagged `User Decision` and tag the item `blocked by` it.

Skipping an item is not reordering. Never move an item or section: propose a move in the report instead, because the order decides what the next session works on.

## 3. Guided opening batch
In guided mode, after the walk, ask everything the run needs in one `AskUserQuestion` call, adding calls only if more than four questions remain, most consequential first:
- The proposed pick, with why it ranks first and the next two picks after it. Options agree, or take one of the next two instead. A reorder comes through `Other`
- The decisions blocking the top threads
- The unclear items, each option stating what happens to the item

Record each decision in the doc or plan it governs, and remove each item the answers resolve, before starting work. Then run, asking later only where an answer would settle something faster or more surely than you could alone.

## 4. Carry out the pick
Route by what the item asks for:
- **A plan not yet executed** - follow the plan-execution rules in the user `CLAUDE.md`
- **Code not yet refined** - invoke `/refine` through the `Skill` tool, passing the item's scope and this run's mode, so it asks neither
- **A plan or design not yet consulted** - invoke `/consult` with the item's subject, in guided mode only. In autonomous mode the item is blocked
- **Anything else** - do the work directly

A skill invoked this way updates the agenda for its own work. Do not repeat its updates.

## 5. Size the run
Decide how much one session should take on, weighing the model, effort level, the risk of the work, the context already used, and token cost. After each item, take the next pick only where it fits comfortably in what remains. Stop at an item boundary rather than leave two items half done, because the user reviews the whole run as one unstaged diff.

An item too large for one session gets a slice that leaves the tree working. Narrow the item to the work that remains.

## 6. Close
Update the agenda as the practice directs, for each item resolved, narrowed, or added. That includes the item it calls for once code is feature-complete and not yet refined.

Report in chat:
- What was done and where you deviated
- Items removed as resolved, each with its evidence
- Items skipped as blocked, by ID, and what each needs from the user, with every other `User Task` and `User Decision` item on the agenda
- Unclear items left in place, and any proposed reorder
- Ideal subject for the next `/next` run, regardless of mode

Keep it a summary. The user often skips it, so anything a later session needs must already be in the diff, the agenda, or a report.
