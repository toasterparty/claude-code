# English
Governs prose that outlives the session; conversation is exempt. Plans for agentic execution invert the density rules - see the last section.

## Density
- Carry a fact the subject cannot state itself, or delete it; deletion is the default fix, rewriting the fallback.
- Why, never what: never restate the code, the diff, the data, or the prompt.
- Stop at the surprising fact; never narrate the journey (alternatives tried, bugs chased, earlier drafts).
- Cite a path or `file:line` only where the location is the news; otherwise state the behavioral effect.
- Length follows the information, not the container: never pad to fill a heading or a bullet's siblings, and never stub a section to satisfy a template - a section with nothing to say does not appear.
- Prefer the doc that cannot go stale: self-describing code beats invariant docs beats narrative docs.

## Banned diction
Delete: `simply`, `just`, `essentially`, `basically`, `actually`, `note that`, `it's worth noting`.
Never use: `robust`, `seamless`, `comprehensive`, `crucial`, `delve`, `powerful`, `elegant`, `unlock`, `landscape`.
Replace: `leverage`/`utilize` -> `use`; `in order to` -> `to`; `prior to` -> `before`; `a number of` -> the count.

## Banned constructions
- `It's not just X, it's Y` / `not only X but Y`: state Y.
- Three of anything where fewer carry the content - adjectives, clauses, bullets.
- Restating the heading or the question before answering it.
- A closing paragraph that re-summarizes the body; `In conclusion`, `Overall`.
- A rhetorical question as an opener.
- Stacked hedges: `might potentially`, `may want to consider`.
- Bullets that read as continuous prose - that is a paragraph.
- Bold mid-sentence; bold only a label or one warning per section.

## Markdown
- Never wrap lines to fit a column limit (paragraphs and bullets included)
- One `#` per file; heading levels never skip. No headings at all in a doc short enough to read whole.
- `-` for bullets, four spaces per nesting level; inline code for every path, flag, and identifier
- No emoji. For the unicode `CLAUDE.md` bans: `...` for the ellipsis, `->` for arrows, `>=`/`<=`, straight quotes, a plain space for the non-breaking space

## By artifact
- Comments: prefer none - names, types, and structure carry the meaning. Good: `timeout = 250  # Cloudflare drops idle connections at 300s`. Weak: `# set the timeout` (restates code), `# was 500, kept dropping` (journey).
- Docstrings: the contract of a public API (inputs, outputs, invariants), never the implementation.
- README: what the thing is, how to build and run it, then stop. Badges, feature lists, architecture tours, and contribution boilerplate only when asked.
- PR description drafts (a requested `pr.md`): one item per behavior change, never per file or per commit, and no item at all for a change with no behavioral effect. State what the system now does differently, plus the review risk if there is one. Good: `Cached entries now expire after an hour instead of living as long as the process`.
- `outbox/` reports: the one artifact where narrative earns its place - deviations, what was verified and how, what was left undone. Density still applies line by line.
- `doc/`: written for an agent arriving cold - no dates, no session references, no `as discussed`.
- User-facing strings: match the surrounding product voice over this file; final wording is the user's call.

## Plans for agentic execution
The executor holds only part of the plan in attention, so completeness outranks brevity: state a fact at every step that needs it.
- Exact repo-relative paths, symbol names, and literal commands, repeated - never `it` or `the file`.
- One numbered step per action, dependencies named, so serial and parallel work are distinguishable.
- Each step states its intent and its verification: the command to run and the result that counts as passing.
- State the done condition and the non-goals; decide every choice the plan raises, or mark it the executor's discretion.

## Audit
Before reporting done, reread every artifact the session wrote and cut what fails the sections above - prose is written hot and read cold. Audit a plan for gaps and ambiguity, never length.
