# Agent-executed plans

## Writing
Completeness outranks brevity: state a fact at every step that needs it. A plan is exempt from the Content rules of `languages/english.md`, the Concise+ rules on leading with the result, narration, and length, and Rhythm, but keeps the Wording rules. Audit it for gaps and ambiguity, never length.
- Exact repo-relative paths, symbol names, and literal commands, repeated - never `it` or `the file`.
- One numbered step per action, dependencies named, so serial and parallel work are distinguishable.
- Each step states its intent and its verification: the command to run and the result that counts as passing.
- State the done condition and the non-goals; decide every choice the plan raises, or mark it the executor's discretion.

## Executing
When executing a plan the user wrote, usually in `<repo>/.agent/inbox/`:
- Read the whole plan first; where the user is on hand, raise ambiguities and conflicts up front, not mid-run
- Then work unattended: resolve gaps as `When the user is away` in `practices/decisions.md` directs, and list deviations in the final report
- On a large task, strip the scaffolding, debug output, and dead code the run introduced, then rerun the project's validation
- Distill process the run uncovered (build quirks, deploy steps, gotchas) into `<repo>/.agent/doc/`
- Verify the result against the plan before reporting done
