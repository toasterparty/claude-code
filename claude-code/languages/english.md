# English
Governs prose that outlives the session; conversation is exempt. Agent-executed plans invert the Content rules - see that section.

## Content
- Every sentence carries a fact its subject cannot state itself, or it goes. Deletion is the default fix, rewriting the fallback.
- Why, never what: never restate the code, the diff, the data, or the prompt.
- Lead with the conclusion, then the support. Never build toward it.
- Stop at the surprising fact. Never narrate the journey (alternatives tried, bugs chased, earlier drafts); a step not yet executed is a proposal and stays.
- Name a symbol, path, or `file:line` only where that location is itself the news. Otherwise say what the code does, not which function does it.
- Prefer the doc that cannot go stale: self-describing code beats invariant docs beats narrative docs. Cut detail specific enough to couple the doc to the implementation.
- Length follows the information, not the container: never pad a heading or match a bullet to its siblings.
- Never restate the heading before answering it, never stub a section to satisfy a template, never close by re-summarizing the body.
- Plain register: no filler adverbs, grandiose adjectives, reflexive triads, stacked hedges, or `not only X but Y`.
- Prefer `,` and `.` over `;` and `-`, keeping `-` for a lead-in label: a clause reaching for either is usually its own sentence.

## Formatting
- Never wrap lines to a column limit: a paragraph or bullet is one unbroken line, however long, and the editor soft-wraps it.
- One `#` per file; no headings in a doc short enough to read whole.
- `-` bullets, four spaces per nesting level; inline code for every path, flag, and identifier.
- Bullets that read as continuous prose are a paragraph. Parallel facts are a table; reasoning is prose.
- Bold is a scanning aid: a lead-in label, or the one value the reader is hunting for. Never a whole sentence, never so often that nothing stands out.
- ASCII only: `-` for em and en dashes (never `--`), `...`, `->`, `>=`/`<=`, straight quotes, plain spaces, no emoji.

## Rhythm
Among phrasings that carry the same meaning, prefer the one whose stresses alternate rather than clumping. Trochaic suits documentation, opening the clause on a stressed content word so the subject and verb land first; iambic suits prose read aloud and sustained narrative with long paragraphs. Meaning, grammar, precision, and paragraph cohesion all outrank the beat, nothing is counted, and no sentence gets an inversion, an archaism, or a weaker word to fix one. The beat never touches layout: the no-wrap rule above holds regardless. Prose on disk converges only opportunistically - a sentence edited for another reason can come back smoother, one left alone stays as it is, and nothing is rewritten for rhythm alone. Exempt: headings, labels, table cells, verbatim output, and all of `Agent-executed plans`.

## Artifacts
- Code: prefer no comment, since names, types, and structure carry the meaning. A docstring gives the contract of a public API (inputs, outputs, invariants), never the implementation.
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
