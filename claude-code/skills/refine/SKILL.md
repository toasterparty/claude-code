---
name: refine
description: Refine a slice of this project behind a strengthened test baseline, weighing simplicity against readability, maintainability, safety, and scale, and raising every bug and behavior change for review. Best on feature-complete code before review.
---

# Refine

Target the best implementation of the behavior already there, weighing simplicity, readability, maintainability, scalability, safety, and security against each other. Simplicity is the usual lever, not the goal: some refinements earn their extra lines. Simple is not short either: a line that costs the reader a second pass is not simpler.

Observable behavior is whatever anything outside the code can see: a public API's results, CLI output and exit codes, file and wire formats, persisted data, error text, side effects, and ordering or timing a caller could notice. Something may depend on any of it, however wrong it looks, and the repo does not show who. Every change made without asking preserves it; Step 5 names the one exception.

- Report directory: `.agent/outbox/refine/`
- Report path: `<report directory>/<YYYYMMDDHHMM>-<sha>.md`, `<sha>` from `git rev-parse --short HEAD`, suffixed `-dirty` when `git status --porcelain -uno` prints anything. Resolve it before the first edit and keep it: it names the tree you inherited
- Branch: `git branch --show-current`, or `detached` where it prints nothing. Resolve it with the report path
- Base branch: `main`

## 1. Scope

Scope is what this pass may touch. File and directory scope is absolute. Diff scope is loose: the diff plus the neighboring code and files it relates to. Diff a commit against the working tree (`git diff <commit>`), never against `HEAD`, so uncommitted work counts. Steer away from code a recent report in the report directory refined, unless it has changed since that report's commit; each report's `Scope` section says what it covered, so read no further.

Scope given with the invocation is used as-is. Otherwise resolve it with `AskUserQuestion` from these options, omitting empty ones and merging staged and unstaged into one uncommitted option when more than four remain:
- The staged diff
- The unstaged diff
- This branch against the base branch
- The previous commit, unless `HEAD~1` is the merge base with the base branch, which makes it the branch diff
- A component, feature, or set of files of your choosing, topical to recent work. Name it in the option

Free text through `Other` covers anything else. A scope too large to carry through every step is cut to a slice, and the report's `Scope` section names the rest.

**Always out of scope:** adding features and implementing plans.

## 2. Load guidance

Find and read the user's and the project's standards that apply to the files in scope: coding, testing, and writing rules, `CLAUDE.md` files, style guides, lint config. Step 5 converges the code on them.

Find the plan behind the scope, if one exists: a document the branch or commit implemented, matched by commit message, branch name, or topic. Read it for the intent the change serves. What it asked for is deliberate however odd it looks.

## 3. Baseline

Find the validation the scope warrants: build, lint, test, static analysis, runtime exercise, whatever the project prescribes.
- None exists: continue without validation, and Step 5 runs conservative
- It exists but is unreachable for now or needs the user (credentials, hardware, a manual exercise): resolve with `AskUserQuestion`

Run it and record the exact commands, warnings and errors, passing test count, and, where the project produces reproducible artifacts, checksums of those that should stay invariant, so pre-existing failures stay distinguishable from yours.

## 4. Close the gaps in validation coverage

Survey the scope and list the changes Step 5 will likely make, noting bug candidates met on the way. Within the code those changes touch, find what no check defends and add a check that would expose a regression. Common gaps, not the full list:
- Untested lines, via the project's coverage tooling
- Behavior, contracts, and invariant outputs
- Failure cases that go unraised or unasserted
- Claims made by documentation or a docstring
- Suppressed errors
- A boundary that only sees well-formed input, like a parser given only valid text or a loader given only files it wrote

Coverage is the net under planned changes, not a goal: gaps outside them go to review.

A new check exposing behavior that looks wrong still asserts what the code does today, with a one-line comment marking it suspect: the suspicion may be mistaken, and the pin keeps any refactor from changing the behavior by accident. Carry it into Step 5 as a bug candidate; an approved fix rewrites the check.

Iterate on the new checks alone until they pass, then repeat Step 3's full run. That is the baseline.

## 5. Refine

One rule: every change preserves observable behavior, except a **Harden** move from the Toolkit, which touches only paths that fail today. Every other behavior change, bug fixes included, goes to `Raise for review`. Within the rule, make any change that leaves the code better by the balance at the top of this skill, with whatever new files, build entries, and config it needs. Merge or delete a check only where another still defends its behavior.

With a solid baseline, be zealous: the user consented to the scope and the validation, and a large restructure is cheaper to attempt than to agonize over. Without validation, be conservative: only high-confidence changes verifiable by reading. Either way, do not manufacture churn in already clean code. After each change, run the narrowest checks covering it, so a failure points at one change, and save the full run for Step 7. Where a safe change depends on a raised one, hold it and fold it into that item's options.

Interrogate every piece of complexity: each layer, option, branch, type, and file must be something the behavior, its maintenance, its safety, or a plausible scale needs, or it goes.

### Bugs

A bug is a defect that plausibly harms observable behavior: a crash, an unhandled failure, an off-by-one, a violated contract, a docstring promise the code breaks, a doc that disagrees with behavior (either side may be the error). Hunt bugs first, since they head the review, and raise every one: never fix one without asking, never sit on one silently. Code can be free of them, and a pass that finds none says so rather than promoting a surprise into a defect. Cover each approved fix with a check that fails before and passes after.

### Toolkit

These moves are where refinement usually hides, not the limit of what is allowed:
- **Delete** - what no caller needs, with the tests, docs, config, and dependencies that only served it
- **Prune comments** - across the scope, touched or not. A comment survives by warning of a pitfall, recording an expensive-to-learn fact, or giving a why the code cannot say, in one line where possible. Delete the self-evident, what a better name would say, decision history, commented-out code, banners, narration, and docstring text beyond a public API's contract. Where a comment props up unclear code, fix the code instead. Expect comment words to fall by over half on a first sweep
- **Document** - docs and docstrings tied to the scope, and anything this pass invalidated (a renamed symbol, moved path, changed command): simplify them, align them with the code's vocabulary (or fix the code where the doc's word is better), and fix grammar and verifiably stale content outright: a path that no longer exists, a command that fails, a symbol since renamed. Verify a correction by running the command or following the path. A doc that disagrees with behavior is a bug
- **Align** - code with the Step 2 standards and, where they are silent, with the project's established patterns: verbs and nouns, error handling, structure, file layout, test style. Every departure is a target, and code doing the same job in two ways converges on the project's most mature and common shape. Tests keep asserted inputs and expected values verbatim
- **Consolidate** - each fact defined in several places (a constant, default, list, schema, mirrored enum, doc restating code) onto one source of truth, and duplicate logic onto one implementation
- **Model** - a concept the code spells out ad hoc (scattered literals, parallel lists, flag combinations) into a type, such as an enum, table, or record, so the next case costs one line. Only where the code already repeats the concept, never for a case nobody has asked for
- **Harden** - handle a failure mode the code leaves unhandled, and validate untrusted input at its boundary, where no plausible input reaches the failure today and every path that succeeds today stays unchanged. A failure plausible today is a bug
- **Extract** - a separable concern into its own file, and a long function's steps into named helpers until its body reads as their summary. Stop before a helper's name says no more than its body, or one idea scatters across files
- **Inline** - pass-through wrappers, single-implementation abstractions, one-caller helpers, single-use variables. A layer is not load-bearing merely because someone wrote it, nor deadweight merely because it is thin: keep one that names a concept, isolates a dependency, or serves as a test seam
- **Flatten** - depth in any form: nested conditionals, loops, ternaries, callbacks, data, type or directory hierarchies. Stop at dense one-liners and chained ternaries, and at structure that mirrors the domain
- **Replace** - hand-rolled code with the standard library, an existing dependency, or a project utility
- **Narrow** - an interface to what is used: `public` to `private`, file to function scope, a parameter type to what the body touches, an optional never absent. Each value takes the least powerful type or structure that does the job: a constant over a macro, an enum over a string, an array over a map, a function over a class
- **Optimize** - time, memory, and CPU cost, as a refactor along another axis: a better algorithm or structure, redundant work removed, where the result reads no worse and the cost matters at a plausible scale
- **Rename** - an identifier until it says what the thing is or returns, and each concept onto the one word the code already uses, in code, comments, tests, and docs
- **Move** - a symbol to the layer owning its concept or the file its callers already open, and declarations, imports, and sections into reading order
- **Format** - with the project's formatter and lint autofixes, never to taste

### Raise for review

Raise rather than make, however good:
- Every bug fix, and any other change to observable behavior
- Where Step 2 found a plan, a change that contradicts it or serves none of its intent
- A deletion, rename, or signature change whose callers cannot all be found and updated (external consumers, reflection, string-keyed dispatch, a symbol named only in config)
- A change safe by every rule above that a reviewer could reasonably reject on taste, where neither the standards nor simplicity settle it: a new abstraction or layout, a naming scheme, a departure from a pattern the authors evidently chose, a pick between two conventions the project uses
- A risky restructure of load-bearing code
- Work too large for this pass

## 6. Review

Open items earlier reports left under `Needs your review` that fall in scope join the raised items: grep the report directory for the scope's paths, skipping items already closed with a `[<status>: ...]` tag. Check each against the current code first, locating it by its description since line numbers drift. An item already addressed, or whose code is gone, closes as `resolved` instead of being raised again.

Walk the user through every raised item with `AskUserQuestion`, one question per item, up to four per call, bugs and other behavior changes first. The user often did not write or recently see this code, so each question explains in plain terms what the code does and why, what is wrong, and the risk.

Options are the item's alternatives, the recommended one first with `(Recommended)` on its label and each description stating what it changes, or a single `Implement` where there is no real alternative. The last option is always `Skip for now`, and a re-raised item offers `Drop` just before it, closing the item for good. Use `preview` for a short before/after where the choice is between code shapes.

Implement what the user chose. An item that gets no answer stays raised in the report.

## 7. Validate

Re-run the baseline. Every signal must match it or improve.

Some deltas are the point: a fix flips a check that encoded the defect, deleted code takes its tests, an extraction splits a test. Note each intended delta in the report, and fix or back out anything else. A backed-out item the user approved goes under `Needs your review` with the failure.

Then audit every prose file this session wrote against the writing standards.

## 8. Report

When the scope is the staged, unstaged, or uncommitted diff, or files git does not track, give the report in chat instead of a file, unless `Needs your review` is non-empty (a skipped or unanswered item, a backed-out fix, deferred work): then write it as a file, since a chat report is lost with the session. Otherwise write it in one `Write`. Either way, use this template: a terse log of fragments, one line per item, no restating the diff. Keep the headings and the `Needs your review` instruction line verbatim and in this order, omitting a section only when it is empty. Give options only where two or more real ones exist.

```
# Refine <branch> <sha>

## Scope
<the slice taken, and what was left for a later pass>

## Changed
- <one line per change class, never per file, like: Inlined 4 one-caller helpers in parser/>

## Changed in review
- <one line per item the user approved in Step 6, a bug fix as: defect, trigger, fix>

## Needs your review
Append `[resolved: <commit or report>]` to an item's first line when you address it.

1. **<Title>** (`path:line`) - <proposed change>.

- (a) <option>
- (b) <option>

Recommendation: (a)

## Baseline
- `<command>` - <anything noteworthy>
- <each intended delta from Step 7, like: 3 tests deleted with parser/legacy.py>
```

Then close each earlier item this pass settled by appending `[<status>: <this report's path, or chat>]` to its first line in its own report: `resolved` when implemented or found addressed, `dropped` on `Drop`, and `moved` when it lands in this report's `Needs your review`. Each open item thus lives in exactly one report.

Name a written report by its repo-relative path and give the highlights in a sentence or two.
