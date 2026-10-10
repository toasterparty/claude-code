# English
Prose that outlives the session follows the Concise+ output style's rules on leading with the result, narration, length, register, structure, and rhythm, plus this file. Read `output-styles/concise-plus.md` in the Claude home directory unless Concise+ is already your output style. Agent-executed plans invert the Content rules and the inherited rules on leading with the result, narration, and length - see that section.

## Content
- Name the reader and what they arrive needing to do before writing: that need decides what goes in.
- Every sentence carries a fact its subject cannot state itself, or it goes. Deletion is the default fix, rewriting the fallback.
- Why, never what: never restate the diff or the data either.
- Stop at the surprising fact. A step not yet executed is a proposal and stays.
- Name a symbol, path, or `file:line` only where that location is itself the news. Otherwise say what the code does, not which function does it.
- Prefer the doc that cannot go stale: self-describing code beats invariant docs beats narrative docs. Cut detail specific enough to couple the doc to the implementation.
- Never restate the heading before answering it or stub a section to satisfy a template.
- Prefer the familiar word and the active voice.
- One term per concept and one concept per term, the code's word where it has one. Never a synonym for variety.
- Define a term the reader may not know where it first appears: the class it belongs to, then what sets it apart. A definition never uses the term itself and never says only what the thing is not.

## Progressive disclosure
Layer instructions and docs so each reader pays only for the depth their task needs: an agent saves context, a human saves reading.
- The always-loaded layer (a `CLAUDE.md`, a skill's description, a README) holds what every reader needs, plus a trigger for each deeper file: when to read it, never a summary of it.
- A deeper file loads only on its trigger and never restates the layer above it.
- Within a file, the common case comes first and detail follows in order of how few readers need it.

## Formatting
- One `#` per file; no headings in a doc short enough to read whole.
- `-` bullets, four spaces per nesting level; inline code for every path, flag, and identifier.
- Dates and times in ISO 8601: `2026-10-09`, `2026-10-09T14:30`.

## Rhythm
Prose that outlives the session converges only opportunistically: a sentence edited for another reason can come back smoother, one left alone stays as it is, and nothing is rewritten for rhythm alone. Agent-executed plans are exempt.

## Artifacts
- README: what the thing is, how to build and run it, then stop. Badges, feature lists, architecture tours, and contribution boilerplate only when asked.
- PR description: one item per behavior change, never per file or commit, none for a change with no behavioral effect. What the system now does differently, plus the review risk if there is one.
- Implementation report: the one place narrative earns its place, for deviations, what was verified and how, and what was left undone.
- Tracked docs, investigations, analyses: written for a reader arriving cold. No session references, no `as discussed`, avoid dates.
- User-facing strings: match the surrounding product voice over this file; final wording is the user's call.

## Agent-executed plans
Completeness outranks brevity: state a fact at every step that needs it.
- Exact repo-relative paths, symbol names, and literal commands, repeated - never `it` or `the file`.
- One numbered step per action, dependencies named, so serial and parallel work are distinguishable.
- Each step states its intent and its verification: the command to run and the result that counts as passing.
- State the done condition and the non-goals; decide every choice the plan raises, or mark it the executor's discretion.

## Audit
Before reporting done, reread every artifact the session wrote and cut what fails the rules above; audit a plan for gaps and ambiguity, never length. Hand the pass to an Opus subagent on fresh context wherever the artifact can be judged without the session's history. On a complex task, expect the pass to end near two thirds of the starting length: cut the section that restates another, and the detail that survived only because it was expensive to learn.
