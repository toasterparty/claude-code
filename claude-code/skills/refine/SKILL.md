---
name: refine
description: Refine a slice of this project behind a strengthened test baseline, weighing simplicity against readability, maintainability, safety, and scale, and raising every bug and behavior change for review. Best on feature-complete code before review.
---

# Refine

Target the best implementation of the behavior already there, weighing simplicity, readability, maintainability, scalability, safety, and security against each other. Simplicity is the usual lever, not the goal: some refinements earn their extra lines, and a line that costs the reader a second pass is not simpler.

Observable behavior is whatever anything outside the code can see: a public API's results, CLI output and exit codes, file and wire formats, persisted data, error text, side effects, and ordering or timing a caller could notice. Every change made without asking preserves it, however wrong it looks; Step 5 names the one exception.

Every pass writes a report, under `practices/reports.md`: read that file before the first edit, and start the report once scope and mode are resolved, with `--skill refine` and a `--subject` naming the component where the scope is one.
- Base branch: `main`

## 1. Scope and mode

Scope is what this pass may touch. File and directory scope is absolute. Diff scope is loose: the diff plus the neighboring code and files it relates to. Diff a commit against the working tree (`git diff <commit>`), never against `HEAD`, so uncommitted work counts. Steer away from code a recent refine report covered, unless it has changed since that report's commit: grep the `scope` and `commit` fields of the refine reports in `.agent/reports/` and its archive, and read no further.

Scope given with the invocation is used as-is. Otherwise resolve it with `AskUserQuestion` from these options, omitting empty ones and merging staged and unstaged into one uncommitted option when more than four remain:
- A component, feature, or set of files of your choosing, topical to recent work. Name it in the option
- The staged diff
- The unstaged diff
- This branch against the base branch
- The previous commit, unless `HEAD~1` is the merge base with the base branch, which makes it the branch diff

Mark exactly one option `(Recommended)`: the scope most worth refining now, judged by how much unrefined code it holds and how recently it changed. List it first, then the rest in the order above. Unlike the other questions in this skill, scope always gets a recommendation, because some scope has to be picked and you have already surveyed the candidates.

Free text through `Other` covers anything else. A scope too large to carry through every step is cut to a slice, and the report's `Scope` section names the rest.

**Always out of scope:** adding features and implementing plans.

Mode is whether the pass may stop for the user, and whether it may fix bugs unasked. Resolve it immediately after scope. A mode given with the invocation (`guided`, `guided-fix`, `autonomous`, or `autonomous-fix`, in any wording) is used as-is. Otherwise ask with `AskUserQuestion`, offering the four below in this order, without a recommendation:
- **Guided** - the user stays on hand to answer questions and review raised items. Interview them with `AskUserQuestion` at any step where their answer would settle something faster or more surely than you could alone, such as the intent behind odd code, which validation route to take, or whether a bug candidate's behavior is deliberate. Items raised for review still wait for Step 6, so the user answers them together, and Step 6 puts the non-trivial decisions among them through `/consult`
- **Guided (fix bugs)** (`guided-fix`) - guided, with every bug that has one clear fix approved in advance, as **Bugs** in Step 5 describes, so Step 6 asks only about the rest. Everything this skill says of guided mode applies to it too
- **Autonomous** - the user steps away, and the pass ends in a report and agenda items. Ask nothing after the mode question, because the user is not there to answer and a pending question stalls the whole pass. Steps 3, 6, and 8 say what changes
- **Autonomous (fix bugs)** (`autonomous-fix`) - autonomous, with every bug that has one clear fix approved in advance, as **Bugs** in Step 5 describes. Everything this skill says of autonomous mode applies to it too

## 2. Load guidance

Find and read the user's and the project's standards that apply to the files in scope: coding, testing, and writing rules, `CLAUDE.md` and `AGENTS.md` files, style guides, lint config. Step 5 converges the code on them.

Find the plan behind the scope, if one exists: a document the branch or commit implemented, matched by commit message, branch name, or topic. Read it for the intent the change serves. What it asked for is deliberate however odd it looks.

## 3. Baseline

Find the validation the scope warrants: build, lint, test, static analysis, runtime exercise, whatever the project prescribes.
- None exists: continue without validation, and Step 5 runs conservative
- It exists but is unreachable for now or needs the user (credentials, hardware, a manual exercise): in guided mode, resolve with `AskUserQuestion`

In autonomous mode, never troubleshoot validation with the user or rely on validation that needs their cooperation. Fix what you can alone, and otherwise fall back to the strongest validation that runs unattended, like a test subset, a build, or a runtime exercise you can drive yourself. Reach for static analysis alone (lint, type checks, compiler warnings, reading) only when nothing stronger runs. List each validation you could not run in the report's `Baseline`, so the user knows what still needs exercising.

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

A new check exposing behavior that looks wrong still asserts what the code does today, with a one-line comment marking it suspect. Carry it into Step 5 as a bug candidate; an approved fix rewrites the check.

Iterate on the new checks alone until they pass, then repeat Step 3's full run. That is the baseline.

## 5. Refine

One rule: every change preserves observable behavior, except a **Harden** move from the Toolkit, which touches only paths that fail today. Every other behavior change, bug fixes included, goes to `Raise for review`. Within the rule, make any change that leaves the code better by the balance at the top of this skill, with whatever new files, build entries, and config it needs. Merge or delete a check only where another still defends its behavior.

With a solid baseline, be zealous: attempt a large restructure rather than agonize over it. Without validation, be conservative: only high-confidence changes verifiable by reading. Either way, do not manufacture churn in already clean code. After each change, run the narrowest checks covering it, and save the full run for Step 7. Where a safe change depends on a raised one, hold it and fold it into that item's options.

Interrogate every piece of complexity: each layer, option, branch, type, and file must be something the behavior, its maintenance, its safety, or a plausible scale needs, or it goes.

### Bugs

A bug is a defect that plausibly harms observable behavior: a crash, an unhandled failure, an off-by-one, a violated contract, a disputed doc (see **Document**). Hunt bugs first and raise every one: never fix one without asking, never sit on one silently. Code can be free of them, and a pass that finds none says so rather than promoting a surprise into a defect. Cover each approved fix with a check that fails before and passes after.

In `guided-fix` and `autonomous-fix` modes, fix a bug without asking where it has one clear fix: the fix Step 6 would offer as a lone `Implement`, or mark `(Recommended)`. Raise a bug whose fixes are a close call, because picking among them is the user's judgment. Every other behavior change is still raised.

### Toolkit

These moves are where refinement usually hides, not the limit of what is allowed:
- **Delete** - what no caller needs, with the tests, docs, config, and dependencies that only served it
- **Prune comments** - across the scope, touched or not. A comment survives by warning of a pitfall, recording an expensive-to-learn fact, or giving a why the code cannot say, in one line where possible. Delete the self-evident, what a better name would say, decision history, commented-out code, banners, narration, and docstring text beyond a public API's contract. Where a comment props up unclear code, fix the code instead. Expect comment words to fall by over half on a first sweep
- **Document** - docs and docstrings tied to the scope, and anything this pass invalidated (a renamed symbol, moved path, changed command): simplify them, align them with the code's vocabulary (or fix the code where the doc's word is better), and fix grammar and stale content outright: a path that no longer exists, a command that fails, a symbol since renamed, a description the behavior contradicts. Verify a correction by running the command or following the path. Where something besides the doc backs its side (a plan, spec, test, commit message, or caller relying on it), the doc is disputed instead, and a disputed doc is a bug
- **Align** - code with the Step 2 standards and, where they are silent, with the project's established patterns: verbs and nouns, error handling, structure, file layout, test style. Every departure is a target, and code doing the same job in two ways converges on the project's most mature and common shape. Tests keep asserted inputs and expected values verbatim
- **Consolidate** - each fact defined in several places (a constant, default, list, schema, mirrored enum, doc restating code) onto one source of truth, and duplicate logic onto one implementation
- **Model** - a concept the code spells out ad hoc (scattered literals, parallel lists, flag combinations) into a type, such as an enum, table, or record, so the next case costs one line. Only where the code already repeats the concept, never for a case nobody has asked for. Dependent bools always qualify, and a combination they reach today but the logic never meant is a bug
- **Harden** - handle a failure mode the code leaves unhandled, and validate untrusted input at its boundary, where no plausible input reaches the failure today and every path that succeeds today stays unchanged. A failure plausible today is a bug
- **Extract** - a separable concern into its own file, and a long function's steps into named helpers until its body reads as their summary. Stop before a helper's name says no more than its body, or one idea scatters across files
- **Inline** - pass-through wrappers, single-implementation abstractions, one-caller helpers, single-use variables. Keep a thin layer that names a concept, isolates a dependency, or serves as a test seam
- **Flatten** - depth in any form: nested conditionals, loops, ternaries, callbacks, data, type or directory hierarchies. Stop at dense one-liners and chained ternaries, and at structure that mirrors the domain
- **Replace** - hand-rolled code with the standard library, an existing dependency, or a project utility
- **Narrow** - an interface to what is used: `public` to `private`, file to function scope, a parameter type to what the body touches, an optional never absent. Each value takes the least powerful type or structure that does the job: a constant over a macro, an enum over a string, an array over a map, a function over a class
- **Optimize** - time, memory, and CPU cost, as a refactor along another axis: a better algorithm or structure, redundant work removed, where the result reads no worse and the cost matters at a plausible scale
- **Rename** - an identifier until it says what the thing is or returns, and each concept onto the one word the code already uses, in code, comments, tests, and docs
- **Move** - a symbol to the layer owning its concept or the file its callers already open, and declarations, imports, and sections into reading order
- **Format** - with the project's formatter and lint autofixes, never to taste

### Raise for review

Raise rather than make, however good:
- Every bug fix not approved in advance, and any other change to observable behavior
- Where Step 2 found a plan, a change that contradicts it or serves none of its intent
- A deletion, rename, or signature change whose callers cannot all be found and updated (external consumers, reflection, string-keyed dispatch, a symbol named only in config)
- A change safe by every rule above that a reviewer could reasonably reject on taste, where neither the standards nor simplicity settle it: a new abstraction or layout, a naming scheme, a departure from a pattern the authors evidently chose, a pick between two conventions the project uses
- A risky restructure of load-bearing code
- Work too large for this pass

## 6. Review

Open agenda items that link an earlier refine report and fall in scope join the raised items, read from that report by their ID. Check each against the current code first, locating it by its description since line numbers drift. An item already addressed, or whose code is gone, closes as resolved instead of being raised again.

Walk the user through every raised item with `AskUserQuestion`, one question per item, up to four per call, bugs and other behavior changes first. Each question explains in plain terms, for a user who may not know this code, what it does and why, what is wrong, and the risk.

Options are the item's alternatives, each description stating what it changes. Mark one `(Recommended)` and list it first only where it is strongly advisable over the rest, giving the reason in its description, because a mark on a close call steers the user away from a judgment that is theirs. Otherwise leave every option unmarked. Where there is no real alternative, offer a single `Implement`. The last option is always `Skip for now`, and a re-raised item offers `Drop` just before it, closing the item for good. Use `preview` for a short before/after where the choice is between code shapes.

Hand the items that are non-trivial decisions to one `/consult` through the `Skill` tool instead, before the direct questions, because a bare question carries too little context for them: a choice between real alternatives whose consequences the user needs context and research to weigh, such as a new abstraction, a behavior change with several fixes, or a pick between two conventions. Its subject lists each item's ID, location, and alternatives, and asks for `Skip for now` on every item and `Drop` on each re-raised one. Ask an item with a lone `Implement`, or a bug with one clear fix, directly.

Implement what the user chose. A new item that gets no answer goes into the report's `Needs your review`. An earlier item that gets none keeps its agenda item and stays in its own report.

In autonomous mode, skip the walkthrough: still close earlier items as resolved where the check above finds them addressed, leave every other earlier item where it is, and carry every new raised item, with its options and any recommendation, into the report's `Needs your review`.

## 7. Validate

Re-run the baseline. Every signal must match it or improve.

Some deltas are the point: a fix flips a check that encoded the defect, deleted code takes its tests, an extraction splits a test. Note each intended delta in the report, and fix or back out anything else. A backed-out item the user approved goes under `Needs your review` with the failure.

Then audit every prose file this session wrote against the writing standards.

## 8. Report

First add one agenda item for each item in `Needs your review`, tagged `User Decision` where it offers the user a choice, grouping the ones that would be resolved together, so the report can carry their IDs. Then complete the report this pass started, in one `Write`. Its `opened` lists the IDs just added, and its `closed` the earlier items this pass settled. The body after the front matter is a terse log of fragments, one line per item, no restating the diff. Keep the headings verbatim and in this order, omitting a section only when it is empty. Give options only where two or more real ones exist, and a `Recommendation` line only where Step 6 would mark one `(Recommended)`.

```
# Refine <subject, or the scope in a few words>

## Scope
<the slice taken, and what was left for a later pass>

## Changed
- <one line per change class, never per file, like: Inlined 4 one-caller helpers in parser/>

## Fixed
- <one line per bug fixed without asking in a fix mode: defect, trigger, fix>

## Changed in review
- <one line per item the user approved in Step 6, a bug fix as: defect, trigger, fix>

## Needs your review
1. **#<id> <Title>** (`path:line`) - <proposed change>.

- (a) <option>
- (b) <option>

Recommendation: (a)

## Baseline
- `<command>` - <anything noteworthy>
- <each intended delta from Step 7, like: 3 tests deleted with parser/legacy.py>
```

Then finish the agenda. Remove every earlier item this pass closed, logged as resolved when implemented or found addressed and as dropped on `Drop`, and any item asking for this scope to be refined. Archive the reports this leaves with nothing open, this one included when `Needs your review` is empty.

Name the report by its repo-relative path and give the highlights in a sentence or two.
