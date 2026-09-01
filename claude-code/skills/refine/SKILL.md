---
name: refine
description: Refine a slice of this project without being told what is wrong with it. Establishes a validation baseline and closes its gaps first, so that deleting, restructuring, and consolidating behind it is safe; changes no observable behavior. Use `/code-review` to hunt bugs in a diff, `/simplify` for a quick quality pass, and this for a deep pass over feature-complete code.
disable-model-invocation: true
---

# Refine

The refinement toolkit - what each verb takes as its object here, and the test it has to pass:
- **Delete** - what no caller needs, and with it the tests, docs, config, and dependencies that existed only to serve it
- **Extract** - a tightly coupled cluster, out into its own function, class, file, component, or unit. The remainder is the point: extraction succeeded when what was left behind got simpler, not when the file got shorter
- **Inline** - a pass-through wrapper, a one-caller helper, a single-use variable, back where it was called. The inverse of extraction and equally available; a layer is not load-bearing merely because someone once wrote it
- **Replace** - a hand-rolled implementation, with one that already exists: the standard library, a dependency already in the manifest, a utility elsewhere in this project
- **Consolidate** - duplicate and near-duplicate logic onto one implementation, and logic that has to be read together into one place
- **Unify** - siblings onto one shape, in naming, argument order, error handling, and return convention, so the odd one out stops costing a second look
- **Narrow** - an interface down to what is actually used: `public` to `private`, file scope to function scope, `#define` to `static const`, a parameter type to what the body touches, an optional that is never absent
- **Reclassify** - a symbol to the layer that owns its concept, or the file its callers already have open
- **Organize** - declarations, cases, imports, and sections into the order that reading them follows
- **Rename** - an identifier, until the comment that explained it can be deleted
- **Reconcile** - the vocabulary onto one word per concept, the word being the one the code already uses. A "block" for what the code calls a `frame` is a synonym to retire, in comments, tests, and docs as much as in identifiers
- **Flatten** - nesting and indirection: guard clauses over nested conditionals, a switch or if/else chain over a nested ternary, a direct call over a layer with one implementation
- **Format** - with the project's formatter and lint autofixes, never to taste

Throughout, `<repo>` is the project root.

## Procedure

### 1. Establish scope

Resolve what is in and out of scope. Bias towards recent work and towards the code that would benefit most, and narrow without asking - one intercorrelated subset refined well beats the whole repository refined mediocrely. Take the module, layer, or dependency cluster you can carry through every step below with room to spare.

#### In scope

Whatever the user named, or is closely related to it. Expect a branch diff, commits, a commit range, staged or unstaged changes, or the name of a module, component, or code unit. A named scope too large to refine well is still narrowed; absent any input, choose the subset yourself. Either way, `Scope` records what you deliberately left for a later pass.

Earlier passes left their reports in `.agent/outbox/refine/`. Read their `Scope` sections before settling on yours, and where the obvious target is one of them, take a sibling or the older code beneath it instead - a slice nobody has picked over yields more per token than a second look at one already refined.

#### Always out of scope

Adding features, implementing plans, and consequential changes to external-facing product behavior.

#### Output file

Every pass writes a report to `.agent/outbox/refine/<sha>.md`, where `<sha>` is `git rev-parse --short HEAD`, suffixed `-dirty` when `git status --porcelain -uno` is non-empty. `-uno` matches what `git describe --dirty` counts: an untracked file is scratch, and the sha still describes the code. A second pass at the same sha overwrites the file.

Both commands run once, before the first edit, and the filename is then fixed for the rest of the pass: the suffix reports the tree you inherited, never the one your own edits produce.

It has five sections, filled in as the pass proceeds: `Scope`, `Fixed`, `Changed`, `Needs your review`, and `Baseline`. `Needs your review` is a numbered list, never bulleted, so the user can answer by number. Write the resolved scope now.

#### Validation the user has to run

If validating this scope needs a person - a manual runtime exercise, credentials, hardware - ask once with `AskUserQuestion` before the first edit. Absent an answer, run the automated subset and name the uncovered surface in the report. Nothing after this step blocks on the user.

### 2. Load guidance

- `<claude home>/languages/english.md`, where `<claude home>` is `$CLAUDE_DIR` when set and `~/.claude` otherwise
- `<claude home>/languages/*.md`, for each language expecting significant edits this session
- `<claude home>/languages/testing.md`, which governs Steps 4 and 6
- `<repo>/CLAUDE.md`, `<repo>/.agent/CLAUDE.md`, and `<repo>/.claude/CLAUDE.md`
- Project documentation that constrains the changes you may make, or that the pass may find to be stale

### 3. Establish the validation baseline

Perform as much of the following as the resolved scope warrants and the project supports:
- Build or compile
- Lint
- Run tests
- Static analysis
- Exercise runtime functionality
- Any validation step the project's documentation or `CLAUDE.md` describes

Record into the `Baseline` section of the output file:
- Compiler warnings and errors
- Passing test count
- Checksums of output files expected to be deterministically invariant
- Logged warnings and errors
- The exact commands that produced all of the above

In the file, not in context: Step 7 reads it back after a long pass, and pre-existing failures have to stay distinguishable from yours.

### 4. Close the gaps in validation coverage

Within the resolved scope, search for what no check currently defends:
- Untested lines, via the project's coverage tooling
- Behavior, contracts, and invariant outputs
- Failure cases that go unraised or unasserted
- A claim or rule stated by documentation or a docstring
- Suppressed errors and failures
- A boundary that only ever sees well-formed input - a parser given only valid text, a loader given only files it wrote

Write checks that would expose a regression in each.

Bound this to the code you expect Step 6 to touch. Coverage here is the net under planned changes, not an end of its own, and a scope can absorb more test-writing than the refinement it exists to protect. An uncovered gap outside that set is named under `Needs your review` and left alone.

A new check can also expose behavior that looks wrong. Do not assert it - a test asserting a bug is a bug with tenure. Carry it into Step 6 as a bug.

### 5. Re-establish the baseline

Repeat Step 3 with the added coverage, iterating until every new check passes, and replace the `Baseline` section with the result. This is the baseline refinement runs against.

### 6. Refine the implementation

Review the code for constructive changes, using the guidance from Step 2 as inspiration. Be zealous - the baseline is what makes a large restructuring cheaper to attempt than to agonize over.

A pass that finds nothing goes looking rather than settling. Where the slice turns out to be already refined, do not manufacture churn to justify the run and do not stop either - return to Step 1 once and take the nearest scope that is not already clean: a sibling module, the layer beneath, the older code the recent work was built on. Steps 3 through 5 run again for the new scope, and the tokens that bought the first survey are not wasted on the second. `Scope` records the slice you found clean alongside the one you redirected to.

Report an empty `Changed` only when the redirect also comes back empty.

#### Bugs

Hunt these first and weight them above everything else here. One defect removed is worth more than any number of files made tidier, so a pass that reports only refactors is a pass that did not look hard enough. Go after the crash, the unhandled failure, the off-by-one, the contract the code violates, the case the docstring promises and the implementation does not deliver.

Fix it outright where the correct behavior is not in question - the code contradicts its own documented contract, or no reasonable reading of this project wants what it currently does. Cover each fix with a check that fails before it and passes after, and record it under `Fixed`: the defect, what triggers it, and the corrected behavior.

Where the right behavior is a product decision, where something may already depend on the defect, or where the fix is consequential and external-facing, raise it instead of fixing it. Never sit on one silently.

#### Clarity

After bugs, this is what the pass is for, and it outranks tidiness of every other kind. Go after:
- Nesting and branching the language can remove outright - guard clauses, early return, a switch or if/else chain in place of a nested ternary. Never write a nested ternary, and unwind every one you find
- Abstractions with a single implementation, indirection that forwards and does nothing else, and duplication where reuse was available
- Identifiers that do not say what the thing is or what it returns
- One concept under two names, one name over two concepts, and jargon standing where a plain word would do
- Logic that has to be read together but lives apart, and units doing enough unrelated work that no name fits them - consolidate the first, extract from the second
- Comments the code beneath them already states (Step 8 sweeps what these leave)
- Tests diverging from `testing.md` - implementation knowledge standing in for the declared contract, a sweep where a named example would read better, boilerplate burying the input. Rewrite these in place - the asserted inputs and expected values survive verbatim, only the structure around them changes; a test whose coverage another already provides is raised rather than deleted

Choose clarity over brevity: explicit code that reads in one pass beats compact code that does not. A shorter line that costs the reader a second pass is not a refinement.

Each of these still has to clear one of the two bars below.

#### Uncontestable changes

For everything that is not a bug fix, the bar is binary. A change belongs to this pass only if it leaves behavior, output, and every public contract observably identical. Make it, then write it to `Changed`, grouping same-class changes onto one line.

Renames, extractions, and moves are the common case to rule on, and the boundary decides them: one confined to a module, where every caller is inside the scope you are already changing, clears the bar and belongs here. One that alters what a module, package, or public API exports does not, however much clarity it would buy - that is a contestable change.

Identical product behavior is necessary and not sufficient. A change to the manifest, to the developer's tooling, or to the baseline itself is contestable whatever it leaves the product doing: adding or dropping a dependency, editing build, CI, or lint configuration, deleting or merging a check. A check, config entry, or dependency that existed only to serve code this pass deleted goes with that code.

#### Contestable changes

Anything that fails those bars is worth raising rather than discarding, however good it is: the bugs held back above, unoptimized implementations, undesirable product behavior, refactors of load-bearing code too risky for a pass with no one watching, a pick between two conventions the project genuinely uses both of, and a deletion whose callers cannot be enumerated - reflection, string-keyed dispatch, a symbol named only in configuration or exported only for a test.

A change ruled out for size rather than risk belongs here too, not only under `Scope`: where every caller sits inside the module but the work exceeds this pass, the proposal goes to `Needs your review` and `Scope` refers to it by number.

Number each entry under `Needs your review`, and give the proposed change, what refinement would gain from it, and the functional impact that kept it out.

### 7. Verify

Re-run the Step 5 commands and compare against the `Baseline` section. Every signal must come back equal or better.

Some deltas are the point rather than a regression - a bug fix flips a check that encoded the defect, deleted dead code takes its tests with it, an extracted function splits one test into several. Where a delta is intended, keep the change and record it in `Fixed` or `Changed` with its justification. Where it is not, fix it or back the change out.

### 8. Correct documentation, prune comments

Reconcile every document Step 2 flagged as suspect, plus anything this pass invalidated - a renamed symbol, a moved path, a changed command - whether or not that document was itself in the resolved scope.

Documentation follows the code's vocabulary, not its own: where the two name a thing differently the document is corrected, even when its word is the better one - fix the code first if it is, then bring the document to it.

A document describing implementation as it no longer is gets corrected to match, not deleted: stale documentation is a defect, and it is fixed like one. Verify the correction rather than assuming it - run the command, follow the path. Delete instead of correcting only where the content should not exist at all, because it violates `english.md` by restating code, narrating the journey, or duplicating a fact that lives elsewhere. Record both under `Changed`.

Then sweep every comment within the resolved scope. Here deletion is the default and rewriting the fallback: on a first sweep of a scope, expect to delete far more than you write, and treat a comment count that barely moved as evidence the rule went unapplied. Where a previous pass already swept this code, that expectation is spent - the survivors earned their place, and deleting them to hit a quota is the failure mode. The rule: a comment survives only by stating a constraint the code cannot show - a reason, an invariant, a caveat, a pointer to why. Delete on sight:
- A comment restating the line or block beneath it
- Narration of a change or an address to the reviewer - `now we`, `note that`, `fixed`, a `TODO` naming no owner or condition
- Section banners and decorative dividers
- Commented-out code
- A docstring on a private helper whose name and signature already say it
- A parameter or return description that repeats the type

Where a comment exists because the code beneath it is unclear, fix the code and delete the comment.

Where this touches code files, re-run the relevant formatting, linting, and validation.

Finally, run the `english.md` audit pass over every artifact this session wrote, the output file included.

### 9. Report done

Name the output file by its path relative to `<repo>`, and give the highlights in no more than a couple of sentences.
