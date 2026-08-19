# English
Governs prose that outlives the session; conversation is exempt. Agent-executed plans invert the Content rules - see that section.

## Content
- Carry a fact the subject cannot state itself, or delete it; deletion is the default fix, rewriting the fallback.
- Why, never what: never restate the code, the diff, the data, or the prompt.
- Stop at the surprising fact; never narrate the journey already taken - alternatives tried, bugs chased, earlier drafts. Steps that have not yet been executed (i.e. proposals) are content, not journey.
- Name a symbol, path, or `file:line` only where that location is itself the news. State what the code does, not which function does it - an identifier dropped in as an aside still costs the reader a lookup.
- Prefer the doc that cannot go stale: Avoid unnecessarily specific details that couples implementation. Self-describing code beats invariant docs beats narrative docs.
- Length follows the information, not the container: never pad to fill a heading or a bullet's siblings
- Never restate the heading or the question before answering it, and never stub a section to satisfy a template - a section with nothing to say does not appear. No closing paragraph that re-summarizes the body.
- Plain register: no filler adverbs, grandiose adjectives, reflexive triads, stacked hedges, or the `not only X but Y` flourish.

## Formatting
- Never wrap lines to fit a column limit (paragraphs and bullets included)
- One `#` per file; heading levels never skip. No headings at all in a doc short enough to read whole.
- `-` for bullets, four spaces per nesting level; inline code for every path, flag, and identifier
- Bullets that read as continuous prose are a paragraph - write the paragraph.
- A flat set of parallel facts is a table; reasoning is prose.
- Use bold as a scanning aid: a paragraph's lead-in label, or the one value the reader is hunting for. Never a whole sentence, never so often that nothing stands out.
- No emoji, no non-ascii: `-` for em and en dashes (never `--`), `...` for the ellipsis, `->` for arrows, `>=`/`<=`, straight quotes, a plain space for the non-breaking space

## Artifacts
- Code: prefer no comment - names, types, and structure carry the meaning. The comment that earns its place states why: `timeout = 250  # Cloudflare drops idle connections at 300s`. A docstring gives the contract of a public API - inputs, outputs, invariants - never the implementation.
- README: what the thing is, how to build and run it, then stop. Badges, feature lists, architecture tours, and contribution boilerplate only when asked.
- PR descriptions: one item per behavior change, never per file or per commit, none at all for a change with no behavioral effect. State what the system now does differently, plus the review risk if there is one.
- Reports and durable docs: Implementation reports are the one place narrative earns its place - deviations, what was verified and how, what was left undone. Git-tracked documentation, investigations and analyses are written for an agent/reader arriving cold: no session references, no `as discussed`, avoid dates.
- User-facing strings: match the surrounding product voice over this file; final wording is the user's call.

## Agent-executed plans
Completeness outranks brevity: state a fact at every step that needs it.
- Exact repo-relative paths, symbol names, and literal commands, repeated - never `it` or `the file`.
- One numbered step per action, dependencies named, so serial and parallel work are distinguishable.
- Each step states its intent and its verification: the command to run and the result that counts as passing.
- State the done condition and the non-goals; decide every choice the plan raises, or mark it the executor's discretion.

## Audit
Before reporting done, reread every artifact the session wrote and cut what fails the rules above. Audit a plan for gaps and ambiguity, never length.
- Hand the pass to a subagent on fresh context wherever the artifact can be judged without the session's history. Opus at medium effort.
- On a complex task, the pass ends when the writing is two thirds the length it started. Cut the section that restates another, and the detail that survived only because it was expensive to learn.
