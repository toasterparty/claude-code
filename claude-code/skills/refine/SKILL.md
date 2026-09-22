---
name: refine
description: Refine a slice of this project without being told what is wrong with it. Establishes a validation baseline and closes its gaps first, so that deleting, restructuring, and consolidating behind it is safe; changes no observable behavior. Use `/code-review` to hunt bugs in a diff, `/simplify` for a quick quality pass, and this for a deep pass over feature-complete code.
disable-model-invocation: true
---

# Refine

The refinement toolkit - what each verb takes as its object, and the test it has to pass:
- **Delete** - what no caller needs, with the tests, docs, config, and dependencies that existed only to serve it
- **Extract** - a coupled cluster into its own function, or a separable concern into its own file, class, component, or unit. Both are first-class moves, not a last resort: a long function becomes a short one calling named helpers, a file carrying several concerns becomes several files. Extraction succeeded when what was left behind got simpler, not when the file got shorter
- **Inline** - a pass-through wrapper, a one-caller helper, a single-use variable, back where it was called. A layer is not load-bearing merely because someone once wrote it
- **Replace** - a hand-rolled implementation with one that already exists: the standard library, a dependency already in the manifest, a utility elsewhere in this project
- **Consolidate** - duplicate and near-duplicate logic onto one implementation, and logic that has to be read together into one place
- **Unify** - siblings onto one shape in naming, argument order, error handling, and return convention
- **Narrow** - an interface to what is actually used: `public` to `private`, file scope to function scope, `#define` to `static const`, a parameter type to what the body touches, an optional that is never absent
- **Reclassify** - a symbol to the layer that owns its concept, or the file its callers already have open
- **Organize** - declarations, cases, imports, and sections into reading order
- **Rename** - an identifier, until the comment that explained it can be deleted
- **Reconcile** - vocabulary onto one word per concept, the one the code already uses. A "block" for what the code calls a `frame` is a synonym to retire in comments, tests, and docs as much as in identifiers
- **Flatten** - guard clauses over nested conditionals, a switch or if/else chain over a nested ternary, a direct call over a layer with one implementation
- **Format** - with the project's formatter and lint autofixes, never to taste

`<repo>` is the project root.

## Procedure

### 1. Establish scope

Bias towards recent work and the code that would benefit most, and narrow without asking: one intercorrelated subset refined well beats the whole repository refined mediocrely. Take the module, layer, or dependency cluster you can carry through every step below with room to spare.

**In scope:** whatever the user named - a branch diff, commits, a range, staged or unstaged changes, a module or component - or what is closely related to it. A named scope too large to refine well is still narrowed; absent any input, choose the subset yourself.

Earlier reports live in `.agent/outbox/refine/`. Read their `Scope` sections first, and where the obvious target was already refined, take a sibling or the older code beneath it instead.

**Always out of scope:** adding features, implementing plans, and consequential changes to external-facing product behavior.

#### Output file

The report goes to `.agent/outbox/refine/<sha>.md`, where `<sha>` is `git rev-parse --short HEAD`, suffixed `-dirty` when `git status --porcelain -uno` is non-empty (untracked files are scratch). Run both once, before the first edit, and keep the filename fixed: the suffix describes the tree you inherited, not your edits. A second pass at the same sha overwrites the file.

Create it now with five headings - `Scope`, `Fixed`, `Changed`, `Needs your review`, `Baseline` - and the resolved scope filled in. Write each later section as its step completes, never held for one write at the end, so an interrupted pass still leaves a report. Then announce the path and scope in one sentence.

#### Report style

The user reads `Needs your review` and skims the rest, so every other section is a terse log: fragments over sentences, one line per item, no justification unless a baseline delta needs one, no restating what a diff shows.
- `Scope` - one line for the slice taken, one for what was deliberately left for a later pass
- `Fixed` - one line per bug: defect, trigger, fix
- `Changed` - one line per change class, never per file (`Inlined 4 one-caller helpers in parser/`)
- `Baseline` - the commands, then a before/after table of the counts and checksums

`Needs your review` is a numbered list, each entry in exactly this shape:

```
1. **<Short title>** (`path:line`) - <the proposed change and what it gains>. <What kept it out of this pass.>
    - *Decision:* (a) <option> (b) <option>
    - *Recommendation:* (a) - <one clause of why>
```

- The entry must stand alone for a reader who has not seen the code: name what the code does before what is wrong with it
- `*Decision:*` appears only where two or more real options exist. Leaving the code as it is never counts as one: inaction is always available and never listed
- `*Recommendation:*` is always present, always on its own line, and says what you implement if the user answers "implement 1" with nothing more

#### Validation the user has to run

If validating this scope needs a person - a manual runtime exercise, credentials, hardware - ask once with `AskUserQuestion` before the first edit. Absent an answer, run the automated subset and name the uncovered surface in the report. Nothing between here and Step 9 blocks on the user.

### 2. Load guidance

- `<claude home>/languages/english.md`, where `<claude home>` is `$CLAUDE_DIR` when set and `~/.claude` otherwise
- `<claude home>/languages/common.md`
- `<claude home>/languages/<language>.md` for each language expecting significant edits
- `<claude home>/languages/testing.md`, which governs Steps 4 and 6
- `<repo>/CLAUDE.md`, `<repo>/.agent/CLAUDE.md`, and `<repo>/.claude/CLAUDE.md`
- Project documentation that constrains your changes, or that the pass may find stale

### 3. Establish the validation baseline

As far as the scope warrants and the project supports: build, lint, test, static analysis, runtime exercise, and any validation the project's docs or `CLAUDE.md` describe.

Record in `Baseline`: compiler warnings and errors, passing test count, checksums of outputs expected to stay invariant, logged warnings and errors, and the exact commands. It lives in the file, not in context, so Step 7 can read it back and pre-existing failures stay distinguishable from yours.

### 4. Close the gaps in validation coverage

Within the code you expect Step 6 to touch, find what no check defends and write a check that would expose a regression:
- Untested lines, via the project's coverage tooling
- Behavior, contracts, and invariant outputs
- Failure cases that go unraised or unasserted
- Claims made by documentation or a docstring
- Suppressed errors
- A boundary that only ever sees well-formed input - a parser given only valid text, a loader given only files it wrote

Coverage is the net under planned changes, not an end of its own. A gap outside that set goes to `Needs your review` and is left alone.

A new check that exposes behavior that looks wrong is not asserted - a test asserting a bug is a bug with tenure. Carry it into Step 6.

### 5. Re-establish the baseline

Repeat Step 3 with the added coverage until every new check passes, and replace `Baseline` with the result.

### 6. Refine the implementation

Use the Step 2 guidance as inspiration and be zealous: the baseline makes a large restructuring cheaper to attempt than to agonize over.

Where the slice turns out already clean, do not manufacture churn and do not stop: return to Step 1 once, take the nearest scope that is not clean (a sibling module, the layer beneath, the older code the recent work sits on), and rerun Steps 3 through 5 for it. `Scope` records both slices. Report an empty `Changed` only when the redirect also comes back empty.

#### Bugs

Hunt these first and weight them above everything else: a pass that reports only refactors did not look hard enough. Go after the crash, the unhandled failure, the off-by-one, the violated contract, the case the docstring promises and the code does not deliver.

Fix it outright where the correct behavior is not in question - the code contradicts its own documented contract, or no reasonable reading of the project wants what it does. Cover each fix with a check that fails before and passes after, and log it under `Fixed`.

Where the right behavior is a product decision, where something may depend on the defect, or where the fix is consequential and external-facing, raise it instead. Never sit on one silently.

#### Clarity

After bugs, clarity outranks every other kind of tidiness. Go after:
- Nesting the language can remove - guard clauses, early return, a switch or if/else chain. Never write a nested ternary, and unwind every one you find
- Long functions: extract the steps into named helpers until the body reads as a summary of them
- Files carrying several concerns: extract each into its own file, so a reader opens only the one they need
- Single-implementation abstractions, forwarding-only indirection, and duplication where reuse was available
- Identifiers that do not say what the thing is or returns
- One concept under two names, one name over two concepts, jargon where a plain word would do
- Logic read together but living apart - consolidate it
- Comments the code already states (Step 8 sweeps the rest)
- Tests diverging from `testing.md` - implementation knowledge standing in for the contract, a sweep where a named example reads better, boilerplate burying the input. Rewrite the structure in place with asserted inputs and expected values kept verbatim; raise, rather than delete, a test whose coverage another already provides

Choose clarity over brevity: a shorter line that costs the reader a second pass is not a refinement. Each change still has to clear one of the two bars below.

#### Uncontestable changes

A change belongs to this pass only if behavior, output, and every public contract stay observably identical. Make it and log it under `Changed`.

Renames, extractions, and moves are decided by the boundary: one confined to a module, with every caller inside the scope you are already changing, clears the bar. A new file inside the module clears it too, including the one-line addition to an existing source list the build needs to see it. One that alters what a module, package, or public API exports is contestable.

Identical product behavior is necessary, not sufficient. Adding or dropping a dependency, editing build, CI, or lint configuration beyond that source-list line, or deleting or merging a check is contestable whatever the product does. A check, config entry, or dependency that existed only to serve code this pass deleted goes with that code.

#### Contestable changes

Anything failing those bars is raised under `Needs your review`, however good it is: bugs held back above, unoptimized implementations, undesirable product behavior, refactors of load-bearing code too risky with no one watching, a pick between two conventions the project genuinely uses, a deletion whose callers cannot be enumerated (reflection, string-keyed dispatch, a symbol named only in config or exported only for a test), and work confined to the module but too large for this pass.

### 7. Verify

Re-run the Step 5 commands and compare against `Baseline`. Every signal must come back equal or better.

Some deltas are the point - a bug fix flips a check that encoded the defect, deleted code takes its tests, an extraction splits one test into several. Keep an intended delta and note it on the change's line. Fix or back out anything else.

### 8. Correct documentation, prune comments

Reconcile every document Step 2 flagged, plus anything this pass invalidated - a renamed symbol, moved path, changed command - whether or not it was in scope. Documentation takes the code's vocabulary: where the two differ, correct the document, or fix the code first if the document's word is better.

Correct stale documentation rather than deleting it, and verify the correction by running the command or following the path. Delete only content that should not exist at all under `english.md`: restated code, narrated history, a fact duplicated elsewhere.

Then sweep every comment in scope, touched by Step 6 or not. The target is zero. A comment survives only by stating a constraint the code cannot show - a reason, an invariant, a caveat - and a survivor is then cut to the fewest words that carry that constraint, one line where possible. A paragraph is almost always one clause of fact wrapped in explanation, and only the clause stays. Delete on sight:
- A comment restating the code beneath it, or explaining what a better name would
- Narration and reviewer address - `now we`, `note that`, `fixed`, a `TODO` naming no owner or condition
- Background, history, and rationale that no longer constrains an edit
- Section banners and dividers
- Commented-out code
- A docstring on a private helper whose signature already says it, and any docstring text beyond a public API's contract
- A parameter or return description that repeats the type or name

Where a comment exists because the code is unclear, fix the code and delete the comment. Expect the comment word count in scope to fall by well over half on a first sweep. A count that barely moved means the rule went unapplied.

Re-run formatting, linting, and validation over touched code files, then run the `english.md` audit over every artifact this session wrote, the report included.

### 9. Report done

Name the report by its path relative to `<repo>` and give the highlights in a sentence or two.

Where `Needs your review` has entries, walk the user through them with `AskUserQuestion`. The user often did not write this code or has not seen it in a long time, so each question carries its own context: what the code does and why it exists, what is wrong or improvable, what each option changes, and the risk. Give that in plain terms before the ask itself.
- One question per entry with a `*Decision:*`. Options are its lettered choices, the recommended one first with `(Recommended)` on its label, each description giving that option's consequence. Use `preview` for a short before/after excerpt where the choice is between code shapes
- Entries without a `*Decision:*` share `multiSelect` questions of up to four entries, one option per entry, asking which to implement
- Never offer inaction as an option: skipping is choosing nothing in a `multiSelect`, or answering `Other`
- Up to four questions per call. Repeat until every entry has been asked

Then implement what was chosen, repeat Step 7, move each implemented entry out of `Needs your review` into `Fixed` or `Changed`, and mark the rest `declined` in place. Close with one sentence naming what was implemented.
