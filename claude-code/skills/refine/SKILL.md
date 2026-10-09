---
name: refine
description: Simplify a slice of this project behind a strengthened test baseline, fixing only unambiguous bugs and asking before any other behavior change. Best on feature-complete code before review.
disable-model-invocation: true
---

# Refine

Target the simplest code that works: the least surface for bugs, the least to review and maintain. Simple is not short: a line that costs the reader a second pass is not simpler.

- Report directory: `.agent/outbox/refine/`
- Report path: `<report directory>/<YYYYMMDDHHMM>-<sha>.md`, where the timestamp is local time, so names sort by creation, and `<sha>` is `git rev-parse --short HEAD`, suffixed `-dirty` when `git status --porcelain -uno` is non-empty. Resolve it before the first edit and keep it, since it describes the tree you inherited
- Base branch: `main`

## 1. Scope

Scope is what this pass may touch. File and directory scope is absolute. Diff scope is loose: include the neighboring code and files it relates to. Diff against a commit from the working tree (`git diff <commit>`), never from `HEAD`. Steer away from code a recent report in the report directory refined, unless it has changed since that report's commit. Each report's `Scope` section says what it covered, so read no further.

Scope given with the invocation is used as-is. Otherwise resolve it with `AskUserQuestion`, omitting empty options, and merging staged and unstaged into one uncommitted option if more than four remain:
- The staged diff
- The unstaged diff
- This branch against the base branch
- The previous commit, unless it equals the branch diff
- A component, feature, or set of files of your choosing, topical to recent work, small enough to carry through every step. Name it in the option

Free text through `Other` covers anything else.

**Always out of scope:** adding features and implementing plans.

## 2. Load guidance

Find and read the user's and the project's standards that apply to the files in scope: coding, testing, and writing rules, `CLAUDE.md` files, style guides, lint config. Step 5 converges the code on them.

## 3. Baseline

Find the validation the scope warrants: build, lint, test, static analysis, runtime exercise, whatever the project prescribes.
- None exists: continue without validation, and Step 5 runs conservative
- It exists but is unreachable for now or needs the user (credentials, hardware, a manual exercise): resolve with `AskUserQuestion`

Run it and record the exact commands, warnings and errors, passing test count, and checksums of outputs that should stay invariant, so pre-existing failures stay distinguishable from yours.

## 4. Close the gaps in validation coverage

Within the code Step 5 will likely touch, find what no check defends and add a check that would expose a regression. Common gaps, not the full list:
- Untested lines, via the project's coverage tooling
- Behavior, contracts, and invariant outputs
- Failure cases that go unraised or unasserted
- Claims made by documentation or a docstring
- Suppressed errors
- A boundary that only sees well-formed input, like a parser given only valid text or a loader given only files it wrote

Coverage is the net under planned changes, not a goal: gaps outside them go to review.

A new check exposing behavior that looks wrong still asserts what the code does today, with a one-line comment marking it suspect: the suspicion may be mistaken, and the pin keeps any refactor from changing the behavior by accident. Carry it into Step 5 as a bug candidate, where a fix rewrites the check.

Iterate on the new checks alone until they pass, then repeat Step 3's full run. That is the baseline.

## 5. Refine

One rule: every change preserves observable behavior (output, side effects, public contracts) or is a bug fix the Bugs section permits outright. Any other behavior change is raised, never made. Within the rule, make any change that leaves the code simpler, with whatever new files, build entries, and config it needs. Merge or delete a check only where another still defends its behavior.

With a solid baseline, be zealous: the user consented to the scope and the validation, and a large restructure is cheaper to attempt than to agonize over. Without validation, be conservative: only high-confidence changes verifiable by reading. Either way, do not manufacture churn in already clean code. After each change, run the narrowest checks covering it, so a failure points at one change, and save the full run for Step 7.

Interrogate every piece of complexity: each layer, option, branch, type, and file must be something the behavior needs, or it goes.

### Bugs

Hunt these first and weight them highest: crashes, unhandled failures, off-by-ones, violated contracts, and docstring promises the code breaks. Code can be free of them, and a pass that finds none says so rather than promoting a surprise into a defect.

Externally observable behavior is whatever anything outside the code can see: a public API's results, CLI output and exit codes, file and wire formats, persisted data, error text, and ordering or timing a caller could notice. Something may depend on any of it, however wrong it looks, and the repo does not show who.

Fix outright only where both hold:
- Correct behavior is not in question: the code contradicts its documented contract, or no reasonable reading of the project wants what it does
- The fix changes nothing externally observable on a path that succeeds today: only internal state, or inputs that currently crash, hang, corrupt data, or fail unhandled

Cover each fix with a check that fails before and passes after. Raise every other bug, including a doc contradicting external behavior, since either side may be the error. Never sit on one silently.

### Toolkit

These moves are where simplification usually hides, not the limit of what is allowed:
- **Delete** - what no caller needs, with the tests, docs, config, and dependencies that only served it
- **Prune comments** - across the scope, touched or not. A comment survives only by warning of a pitfall or recording an expensive-to-learn fact, in one line where possible. Delete the self-evident, what a better name would say, decision history, commented-out code, banners, narration, and docstring text beyond a public API's contract. Where a comment props up unclear code, fix the code instead. Expect comment words to fall by over half on a first sweep
- **Document** - docs and docstrings tied to the scope, and anything this pass invalidated (a renamed symbol, moved path, changed command): simplify them, align them with the code's vocabulary (or fix the code where the doc's word is better), and fix stale content and grammar outright, never raised. Verify a correction by running the command or following the path
- **Conform** - code to the Step 2 standards: verbs and nouns, error handling, structure, test style. Every departure is a target. Where they are silent, siblings take the project's most mature and common shape. Tests keep asserted inputs and expected values verbatim
- **Consolidate** - each fact defined in several places (a constant, default, list, schema, mirrored enum, doc restating code) onto one source of truth, and duplicate logic onto one implementation
- **Extract** - a separable concern into its own file, and a long function's steps into named helpers until its body reads as their summary
- **Inline** - pass-through wrappers, single-implementation abstractions, one-caller helpers, single-use variables. A layer is not load-bearing merely because someone wrote it
- **Flatten** - depth in any form: nested conditionals, loops, ternaries, callbacks, data, type or directory hierarchies
- **Replace** - hand-rolled code with the standard library, an existing dependency, or a project utility
- **Narrow** - an interface to what is used: `public` to `private`, file to function scope, a parameter type to what the body touches, an optional never absent. Each value takes the least powerful type or structure that does the job: a constant over a macro, an enum over a string, an array over a map, a function over a class
- **Optimize** - time, memory, and CPU cost, as a refactor along another axis: a better algorithm or structure, redundant work removed, where the result reads no worse
- **Rename** - an identifier until it says what the thing is or returns, and each concept onto the one word the code already uses, in code, comments, tests, and docs
- **Move** - a symbol to the layer owning its concept or the file its callers already open, and declarations, imports, and sections into reading order
- **Format** - with the project's formatter and lint autofixes, never to taste

### Raise for review

Raise rather than make, however good:
- A bug fix the Bugs section does not permit outright, and any other change to externally observable behavior
- A deletion, rename, or signature change whose callers cannot all be found and updated (external consumers, reflection, string-keyed dispatch, a symbol named only in config)
- A change safe by every rule above that a reviewer could reasonably reject on taste, where neither the standards nor simplicity settle it: a new abstraction or layout, a naming scheme, a departure from a pattern the authors evidently chose, a pick between two conventions the project uses
- A risky restructure of load-bearing code
- Work too large for this pass

## 6. Review

Open items that earlier reports left under `Needs your review` and that fall in scope join the raised items: grep the report directory for the scope's paths, skipping items already closed with a `[<status>: ...]` tag. Check each against the current code first, locating it by its description since line numbers drift. An item already addressed, or whose code is gone, is closed as `resolved` rather than raised.

Walk the user through every raised item now with `AskUserQuestion`, one question per item, up to four per call, behavior changes first. The user often did not write or recently see this code, so each question explains in plain terms what the code does and why, what is wrong, and the risk.

Options are the item's alternatives, the recommended one first with `(Recommended)` on its label and each description stating what it changes, or a single `Implement` where there is no real alternative. The last option is always `Skip for now`, and a re-raised item offers `Drop` just before it, closing the item for good. Use `preview` for a short before/after where the choice is between code shapes.

Implement what the user chose.

## 7. Validate

Re-run the baseline. Every signal must match it or improve.

Some deltas are the point: a fix flips a check that encoded the defect, deleted code takes its tests, an extraction splits a test. Note each intended delta in the report, and fix or back out anything else. A backed-out item the user approved goes under `Needs your review` with the failure.

Then audit every prose file this session wrote against the writing standards.

## 8. Report

Write the report in one `Write` from this template: a terse log of fragments, one line per item, no restating the diff. Keep the headings and the `Needs your review` instruction line verbatim and in this order, omitting a section only when it is empty. Give options only where two or more real ones exist.

```
# Refine <sha>

## Scope
<the slice taken, and what was left for a later pass>

## Fixed
- <defect>, <trigger>, <fix>

## Changed
- <one line per change class, never per file, like: Inlined 4 one-caller helpers in parser/>

## Changed in review
- <one line per item the user approved in Step 6>

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

Then close each earlier item this pass settled by appending `[<status>: <this report's path>]` to its first line in its own report: `resolved` when implemented or found addressed, `dropped` on `Drop`, and `moved` when it lands in this report's `Needs your review`. Each open item thus lives in exactly one report.

Name the report by its repo-relative path and give the highlights in a sentence or two.
