# Decisions for the user
Put a non-trivial decision to the user through `/consult`, invoked with the `Skill` tool, never as a bare question, because a bare question carries too little context for it. Ask the rest directly. Where `/consult` is not installed, ask every decision directly, giving each the context a non-trivial one needs.

A decision is non-trivial when any of these holds:
- The options differ in behavior a client, user, or operator can observe, such as a reply or error code, an ordering, a timing, a wire format, or a log line, or in a resource budget such as memory, flash, or a task
- It concerns design, naming, a public interface, or project policy, and two reasonable people could choose differently
- Weighing it needs context the user is unlikely to remember, such as how the code works, a protocol's details, or why a plan chose what it did
- An agent already made it without asking, for example an item a report lists under `Decided without asking` or `Needs your review`, or a choice that has already landed. Asking whether to keep it is not a confirmation, because the user never weighed it: it is the same decision, with the landed choice as one option

Ask directly instead:
- A confirmation of something the user already decided or said
- A fact only the user knows, such as which hardware is on hand
- A pick between agenda items, or an item's fate: remove, keep, or skip
- A bug with one clear fix, or a change whose only option is `Implement`

Ask neither way an agent-owned decision: one of a class the project's instructions assign to the agent, such as tuning constants or code structure. This holds even where a bullet above would make it non-trivial, because the user delegated the class to save their attention, and asking hands it back. The agent makes it, and a run that made any records them in its report under one review item, as `practices/agenda.md` describes, so the user can veto them in bulk. A decision the instructions leave to the user, or do not mention, stays under the rules above.

Before asking, check each factual premise the question rests on against the code, data, or log that settles it, and state the evidence in the question. A claim relayed from another agent, such as a subagent's "this never happens", is a premise: restate the search it covered, or the user weighs a claim nobody verified.

When unsure, consult. A consult costs the user a few minutes, while a misjudged bare question costs a round of answers they could not give.

## When the user is away
Once the user has stepped away, at the point the skill, plan, or user names, a run asks nothing, because nobody is there to answer and a pending question stalls the whole run. Sort each question that nothing written settles, in this order:
1. An agent-owned decision is made and logged, never raised.
2. A choice whose reversal is a small change is built on its likeliest answer and logged. A guess that a later session undid has cost a full rebuild, so a costlier reversal falls to step 3.
3. Anything else is raised, and the run takes another thread.

Logged means listed in the run's report, or a subagent's result, with the alternative given up. Raised means an agenda item tagged `User Decision`, with the work that needs it tagged `blocked by` it. A skill may raise more than this, as `/refine` raises every behavior change.

A subagent sorts its questions the same way but raises to its parent session, in its result, since only the top-level session edits the agenda. A parent that orchestrates stands in as the interim user for what its subagents raise and decides each question itself, as `practices/orchestration.md` describes.
