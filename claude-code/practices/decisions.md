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

When unsure, consult. A consult costs the user a few minutes, while a misjudged bare question costs a round of answers they could not give.
