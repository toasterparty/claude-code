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
- **Orchestrate** - the user steps away while the session drives an objective larger than one session's context, delegating to subagents. Step 6. Offer it only where the session model is Opus or above, because the orchestrator must be able to judge and correct every subagent below it. Asked for by invocation on a lower model, run Autonomous instead and say why in the close

Mark one intent `(Recommended)` and list it first only where the agenda, read by its tags alone, makes it a clear winner, giving the reason in its description.

Any other text given with the invocation names the section to work in, or for Orchestrate the objective.

In Unblock and Review the user is on hand: ask wherever an answer would settle something faster or more surely than you could alone. Before putting any decision to the user, read `practices/decisions.md`, which sends each one to `/consult` or a direct question. It counts a decision an earlier agent made without asking as non-trivial, even when the question looks like a confirmation to keep it. In Autonomous and Orchestrate, ask nothing after the intent question, because the user is not there to answer and a pending question stalls the whole run. A plan ambiguity that gates the work becomes a `User Decision` item, and one that does not is resolved in the plan's spirit and logged in the report.

Once the intent is Autonomous or Orchestrate, start the report step 9 describes, before the walk's first edit.

## 2. Walk the agenda
Walk sections top to bottom and items top to bottom within each, opening a split-out section's own file when the walk reaches it, and classify each item:
- **Resolved** - the evidence the agenda practice names proves it done: a commit containing its change, the described behavior or file present in the repo, a linked document gone with its work finished. Remove it, logging the removal and clearing the `blocked by` tags that named it
- **Unclear** - only partial or circumstantial evidence that it is done. Where the user is on hand, ask. Otherwise leave it and flag it in the close. Never remove an item on a guess
- **Blocked** - it needs something only the user can give: a decision not yet made, a task outside the agent's reach, validation that needs their hardware or credentials, or a `/consult` while the user is away. Or it waits on another item still open. Autonomous and Orchestrate skip it, along with the items `blocked by` it
- **Open** - doable now

How far the walk goes depends on the intent. Unblock and Review walk the whole agenda, because every item is a candidate. Autonomous walks until the first open item, the pick, and each later pick in the same run extends the walk down to it. Orchestrate walks the items its objective covers, and none where the objective is new work no item names. A section given with the invocation limits every walk to that section. A full reconciliation against `inbox/` and the reports belongs to `/tidy`, not here.

Trust the tags before re-deriving anything. An item tagged `User Task` or `User Decision`, or `blocked by` an item still on the agenda, is blocked without a check. A `blocked by` naming an ID no longer on the agenda is stale: clear it and classify the item afresh. An item stamped `open @<commit>` is not resolved, unless a commit since that one touches what it names. Record what the check confirms, so the next walk can skip it: stamp `open @<HEAD>` on each item checked and found still open, and add the tag for each blocker found that the item did not yet name.

Never make a user's decision on your own lean to unblock an item, even where you would recommend an answer. Work another thread instead: there are usually several, and progress there costs the user nothing to review. Where only part of an item depends on the open decision, carry out the part that does not, and narrow the item to what remains. Where the decision has no item of its own yet, add one tagged `User Decision` and tag the item `blocked by` it.

Never move an item or section without the user's agreement, because the order decides what the next session works on. Skipping an item is not reordering. Where the user is away, propose a move in the close instead.

## 3. Unblock
Hand every non-trivial decision in the walk to one `/consult`, whether it is a `User Decision` item or a choice an earlier run made without asking that an item or its linked report puts up for review, its subject naming each item's ID and linked document, so the decisions share one round of research. Then ask the remaining decision items and every unclear item directly, in rounds of up to four questions, in agenda order unless a decision blocks more work than the ones above it. Each direct question gives just enough context for a user who may not remember the item, drawn from its linked document, and each option states what it leads to. Mark one `(Recommended)` only where it is strongly advisable. Record each answer, from the consult or a direct question, in the doc it governs, never an `inbox/` asset, or where none exists as a sub-bullet on the item it unblocks, then remove or narrow the item and clear the `blocked by` tags it releases.

Then walk the `User Task` items, one at a time in agenda order. Give the exact steps: commands to run, where to look, and the result that counts as done. Verify each task the user reports done against evidence you can check yourself where one exists, such as a CI run, a file, or a log, then remove the item. A task the user cannot do now stays, with anything learned added as a sub-bullet.

Then close as step 9 directs, listing in chat the items this session unblocked, since the next Autonomous run can take them.

## 4. Review
Brief in chat, by section in agenda order: a line each for the open items worth doing next, with why the top one ranks first, then every item the walk removed as resolved or left unclear, and every move you would propose.

Then ask in one `AskUserQuestion` batch, adding calls only if more than four questions remain:
- The pick: the top open item, the next two as alternatives, and `None` to stop after the cleanup. Another item or a reorder comes through `Other`
- Each unclear item, and each stale section whose date has fallen well behind its neighbors', each option stating what happens to it
- Each proposed move of an item or section

Apply the answers before any other work: remove and log what the user settles, and make the moves they agree to. Then carry out the pick with the user on hand, as step 7 routes it, or stop where they picked none.

## 5. Autonomous
Carry out the pick as step 7 routes it, then take the next pick while the session has room, as step 8 sizes it.

## 6. Orchestrate
Take the objective from the invocation, or else the open items of the topmost section that has any. Break it into delegations ordered by dependency, each with a plan written under `practices/plans.md`, and hand each to the cheapest worker that can be trusted with it:
- **Sonnet subagent** - implementation whose plan leaves no judgment open: exact files, steps, and verification
- **Opus subagent** - work that needs judgment: a design gap the plan cannot close in advance, a risky change to load-bearing code, a `/refine`, a review of another subagent's diff
- **Inline** - work where writing the plan would cost more than doing it

Delegate only down the ladder Fable, Opus, Sonnet: a Fable session may hand work to Opus or Sonnet subagents, an Opus session to Opus or Sonnet, and never to a model above its own, because a weaker model cannot be trusted to judge a stronger one's work. A subagent may delegate further on the same terms. Sonnet never delegates.

Subagents edit the working tree directly, never a worktree, whose branch and merge back would need git writes the rules forbid. Run subagents in parallel only on disjoint files, and never while one edits what another reads. Only this session edits the agenda. Each subagent's result lists its agenda items, the choices it made at its own discretion, and what it left untested, which feed the report.

Verify each delegation before anything builds on it: read its diff and rerun the validation its plan names. A delegation that fails gets one retry with a corrected plan, or is taken inline. Before a delegation builds on substantial code an earlier one landed, hand an Opus subagent `/refine` in `autonomous` mode on that code, because each layer built on unrefined code compounds its debt. That subagent takes IDs from `next-id.sh` and writes its refine report as usual, but returns its agenda items instead of adding them: add them yourself, and archive its report if they leave it nothing open.

Stop when the objective is met, when every remaining thread is blocked on the user, or when the context left can no longer verify another delegation.

## 7. Carry out a pick
Route by what the item asks for:
- **A plan not yet executed** - follow the execution rules in `practices/plans.md`
- **Code not yet refined** - invoke `/refine` through the `Skill` tool, passing the item's scope and the mode, `guided` where the user is on hand and `autonomous` otherwise, so it asks neither
- **A plan or design not yet consulted** - invoke `/consult` with the item's subject, only where the user is on hand. Otherwise the item is blocked
- **Anything else** - do the work directly

A skill invoked this way in this session updates the agenda for its own work. Do not repeat its updates.

## 8. Size the run
Decide how much one session should take on, weighing the model, effort level, the risk of the work, the context already used, and token cost. After each item, take the next pick only where it fits comfortably in what remains. Stop at an item boundary rather than leave two items half done, because the user reviews the whole run as one unstaged diff.

An item too large for one session gets a slice that leaves the tree working. Narrow the item to the work that remains.

## 9. Close
Update the agenda as the practice directs, for each item resolved, narrowed, or added. That includes the item it calls for once code is feature-complete and not yet refined.

### Report
Autonomous and Orchestrate runs write a report under `practices/reports.md`, with `--skill next` and the intent as `mode`, because the user reviews a run they did not watch after its chat is gone. A run that handed no implementation to a subagent (Explore does not count), decided nothing without asking, and left nothing untested deletes its report at the close and reports in chat alone: the one case where a report is deleted rather than archived, since it records nothing.

A decision made without asking is a choice the work forced that no plan, doc, or answer settled, made in the spirit of the item: never a decision an item tags `User Decision`. Before writing the report, so it can carry the IDs, add agenda items linking it: one per group of decisions the user would confirm or veto together, tagged `User Decision`, and one per group of untested work that would be exercised together, tagged `User Task` where only the user can exercise it. The body after the front matter is:

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
- Items removed as resolved, each with its evidence
- Items skipped as blocked, by ID, and what each needs from the user, with every other `User Task` and `User Decision` item on the agenda
- Unclear items left in place, and any proposed reorder
- The intent and subject best suited to the next `/next` run

Keep it a summary. The user often skips it, so anything a later session needs must already be in the diff, the agenda, or a report.
