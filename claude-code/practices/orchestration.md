# Orchestration
An orchestrator is a session that drives an objective through subagents and does none of the work itself. Orchestration suits an objective no single session could finish: a large technical hurdle, a wide verification gap, an analysis spanning more material than one context holds. The user who asks for it expects substantially more progress than one session's top task or two. Only Opus and above orchestrate, because the orchestrator must be able to judge and correct every subagent below it.

## Delegating
Break the objective into delegations ordered by dependency, each with a plan written under `practices/plans.md`, and hand each to the cheapest worker that can be trusted with it:
- **Sonnet subagent** - work whose plan leaves no judgment open: exact files, steps, and verification
- **Opus subagent** - work that needs judgment: a design gap the plan cannot close in advance, a risky change to load-bearing code, a `/refine`, a review of another subagent's work

Do no work inline, however small, because the orchestrator's context is held in reserve for judging results and handling what its subagents did not expect. The orchestrator writes plans, reads diffs and findings, runs validation, and keeps the records.

Delegate only down the ladder Fable, Opus, Sonnet: a Fable session may hand work to Fable, Opus, or Sonnet subagents, an Opus session to Opus or Sonnet, and never to a model above its own, because a weaker model cannot be trusted to judge a stronger one's work. A subagent may delegate further on the same terms. Sonnet never delegates.

An agenda item tagged with a model, as `practices/agenda.md` describes, goes to a subagent on that model without re-judging, because a session at or above that level already judged it. An item tagged above the orchestrator's own model stays out of the run.

Subagents edit the working tree directly, never a worktree, whose branch and merge back would need git writes the rules forbid. Run subagents in parallel only on disjoint files, and never while one edits what another reads. Each plan states the line on open questions below, since a subagent never reads this file, and asks for a result listing the choices the subagent made at its own discretion, the questions it raised, what it left untested, and any follow-up work it found.

## Open questions
The user is away, so an orchestrated run asks nothing, and each subagent sorts its open questions as `When the user is away` in `practices/decisions.md` directs, raising to the orchestrator what it does not settle. The orchestrator stands in for the user on every question its subagents raise, the items a `/refine` it dispatched raises included, and makes the call itself, choices the user would see or feel included. It tolerates a costlier reversal than a single session would, because a run that halts at every gap makes little progress, and a finished prototype is cheaper to correct than a stalled one. Each call is logged with the alternative given up, so the user can review the calls the orchestrator powered through after the run. A raised question blocks only where its likeliest answer would contradict a written design or plan, or where a wrong guess would throw away most of the objective's work. Work around a blocked question and list it at the close. Expect few.

Hand each call back to the subagent that raised it, continuing that subagent with its context where the harness allows (`SendMessage` in Claude Code), or else to a new delegation whose plan carries the answer.

## Verifying
Verify each delegation before anything builds on it: read its diff or findings, and rerun the validation its plan names. Once relayed, a subagent's claim is the orchestrator's claim: a "never happens", "clean", or "verified" in the close states the search it covered, such as the inputs, cases, or files checked, because a claim wider than its search once reached the user as a premise. A delegation that fails gets one retry with a corrected plan, then goes to an Opus subagent.

Before a delegation builds on substantial code an earlier one landed, hand an Opus subagent `/refine` in `autonomous-fix` mode on that code, because each layer built on unrefined code compounds its debt. Its plan says an orchestrator dispatched it, so the pass returns its raised items to the orchestrator, as `/refine` step 6 describes, and the orchestrator decides them under `Open questions`.

## Stopping
Stop when the objective is met, when every remaining thread waits on a blocking question or an action only the user can take, when the next piece of work is unrelated to what the run has finished, or when the context left can no longer verify another delegation. Before the close, wherever a subagent touched source, run `git status --short` and the project's tests, because a subagent can leave scratch edits behind.

The close lists what was done and how it was verified, each logged decision with the alternative given up, each blocked question, and the work left untested.
