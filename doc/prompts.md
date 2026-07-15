# Reusable Prompts

Replace any text in angle brackets (`<>`) with what is relevant for your current task.

## Create high-level implementation plan from high-level requirements/plan document

```
You are a very costly model to run. The benefit you provide is upfront clarity against the highest risks that exist in the current plan. Do not get bogged down in the documenting details which any competent implementing agent could easily handle for less cost. Delegate fact-finding to explorer subagents.

Read <task.md>, investigate ambiguities, unknowns and unresolved decisions - then write a high-level plan optimized for another less costly agentic AI to execute (e.g. Opus) to <task-implementation.md>.
```

## Optimize AI workflow

```
Review the strategies, values, prose, etc. codified in skill and CLAUDE.md files. Raise any contradictory or inefficient design, then revise the contents to optimize for better plan outcomes and fewer token spend when executed by Claude Code Opus.
```
