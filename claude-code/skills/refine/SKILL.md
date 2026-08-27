---
name: refine
description: Refine a slice of this project without being told what is wrong with it. Establishes a validation baseline and closes its gaps first, so that deleting, restructuring, and consolidating behind it is safe; changes no observable behavior. Use `/code-review` to hunt bugs in a diff, `/simplify` for a quick quality pass, and this for a deep pass over feature-complete code.
disable-model-invocation: true
---

# Refine

Improve a slice of this project without being told what is wrong with it.

Refinement:
- Preserves existing behavior
- Maximizes cohesiveness, readability, and maintainability
- Minimizes unnecessary complexity, regression risk, and contradiction

The toolkit includes, but is not limited to, deleting, refactoring, reclassifying, organizing, consolidating, extracting, and formatting.

Throughout: `<repo>` is the project root, and `<claude home>` is `$CLAUDE_DIR` when set, otherwise `~/.claude`.

Where surveying the project would crowd the orchestrator's context, delegate the fact-finding to Explore subagents and take back only the findings. On a project small enough to hold, read it directly - a spawn costs more than it saves.

## Procedure

### 1. Establish scope

Resolve what is in and out of scope. Bias towards recent work and towards the code that would benefit most, and narrow without asking - one intercorrelated subset refined well beats the whole repository refined mediocrely. Take the module, layer, or dependency cluster you can carry through every step below with room to spare.

#### In scope

Whatever the user named, or is closely related to it. Expect a branch diff, commits, a commit range, staged or unstaged changes, or the name of a module, component, or code unit. A named scope too large to refine well is still narrowed; absent any input, choose the subset yourself. Either way, `Scope` records what you deliberately left for a later pass.

#### Always out of scope

Adding features, implementing plans, and consequential changes to external-facing product behavior.

#### Output file

Every pass writes a report to `.agent/outbox/refine-<sha>.md`, where `<sha>` is `git rev-parse --short HEAD`, suffixed `-dirty` when `git status --porcelain` is non-empty. A second pass at the same sha overwrites the file.

It has four sections, filled in as the pass proceeds: `Scope`, `Changed`, `Needs your review`, and `Baseline`. Write the resolved scope now.

#### Validation the user has to run

If validating this scope needs a person - a manual runtime exercise, credentials, hardware - ask once with `AskUserQuestion` before the first edit. Absent an answer, run the automated subset and name the uncovered surface in the report. Nothing after this step blocks on the user.

### 2. Load guidance

- `<claude home>/languages/english.md`
- `<claude home>/languages/*.md`, for each language expecting significant edits this session
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

In the file, not in context: Step 7 reads it back after a long pass, and the failures already present before you touched anything have to stay distinguishable from yours.

### 4. Close the gaps in validation coverage

Within the resolved scope, search for what no check currently defends:
- Untested lines, via the project's coverage tooling
- Behavior, contracts, and invariant outputs
- Failure cases that go unraised or unasserted
- A claim or rule stated by documentation or a docstring
- Suppressed errors and failures
- A boundary that only ever sees well-formed input - a parser given only valid text, a loader given only files it wrote

Write checks that would expose a regression in each.

A new check can also expose behavior that looks wrong. Pin the current behavior only where something depends on it, and record the suspicion under `Needs your review` either way. A test asserting a bug is a bug with tenure.

### 5. Re-establish the baseline

Repeat Step 3 with the added coverage, iterating until every new check passes, and replace the `Baseline` section with the result. This is the baseline refinement runs against.

### 6. Refine the implementation

Deliberately open to interpretation: review the code for constructive changes, using the guidance from Step 2 as inspiration. Be zealous - the baseline is what makes a large restructuring cheaper to attempt than to agonize over.

#### Uncontestable changes

The bar is binary. A change belongs to this pass only if it leaves behavior, output, and every public contract observably identical. Make it, then write it to `Changed`, grouping same-class changes onto one line.

#### Contestable changes

Anything that fails that bar is worth raising rather than discarding, however good it is. Look for bugs, unoptimized implementations, undesirable product behavior, and refactors of load-bearing code too risky for a pass with no one watching.

Record each under `Needs your review`: the proposed change, what refinement would gain from it, and the functional impact that kept it out.

### 7. Verify

Re-run the Step 5 commands and compare against the `Baseline` section. Every signal must come back equal or better.

Some deltas are the point rather than a regression - deleted dead code takes its tests with it, an extracted function splits one test into several. Where a delta is intended, keep the change and record it in `Changed` with its justification. Where it is not, fix it or back the change out.

### 8. Update documentation

Update documentation that describes implementation as it no longer is, or that violates `english.md` - restating code, narrating the journey, duplicating a fact that lives elsewhere.

Always sweep code comments within the resolved scope - comments are documentation, and where excess prose collects.

Where this touches code files, re-run the relevant formatting, linting, and validation.

Finally, run the `english.md` audit pass over every artifact this session wrote, the output file included.

### 9. Report done

Name the output file by its path relative to `<repo>`, and give the highlights in no more than a couple of sentences.
