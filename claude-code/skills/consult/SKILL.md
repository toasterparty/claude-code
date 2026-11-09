---
name: consult
description: Interview the user for the decisions, values, judgments, rankings, and undiscoverable facts that should steer a subject. Use at a contestable decision costly to reverse, or when the user takes a bird's-eye view or is reinforcing a plan, concept, or design before implementing it. Never during an unattended plan run.
argument-hint: "[subject]"
---

# Consult

Sessions narrow: agents silently rule out alternatives. The aim is enough bird's-eye guidance that the user is satisfied with the outcome without nitpicking its implementation.

Report path: `.agent/outbox/consult/<YYYYMMDDHHMM>-<subject-slug>.md`

## 1. Subject
Subject given with the invocation is used as-is. Invoking the skill yourself, name the subject from the decision at hand. Otherwise resolve it with a `multiSelect` `AskUserQuestion`, naming each option concretely and omitting empty ones, or pick the likeliest subject where the tool is unavailable:
- The current session topic, or a related one
- Recent git activity: uncommitted changes, recent commits, or the branch diff against the default branch
- The project as a whole
- A specific plan, requirements set, or design

## 2. Research
Read the subject, the standards that govern it, and earlier reports on it in `.agent/outbox/consult/`, where on conflict the newest wins. Stop once more reading would not change the questions. Look for:
- Contradictions: a plan against the implementation, a doc against the code, one requirement against another, anything against the standards. Each becomes a question unless evidence settles it
- Decisions already made, by anyone: everything is open to challenge, including the user's own decisions, plans, and standards
- Alternatives the conversation never considered, and framings a reasonable person would reject
- Facts only the user can supply

Then cut any value question two reasonable people would not disagree on, and any candidate research can answer or whose answer would not change the outcome. Decide those yourself.

## 3. Ask
Ask in rounds of up to four questions, most consequential first. Let answers spawn follow-ups and retire questions. Stop when nothing left would change the outcome, or when the user says to. An answer through `Other` can redefine the question: follow what it says. To rank, pit the top contenders against each other or invite an ordering through `Other`, since the tool has no ranking input.

Each question:
- **Probes a value, unless asking a fact** - implementation is secondary. Not "Redis or an in-process cache?" but "Is losing cached state on restart acceptable to avoid running another service?", with the implementations in the option descriptions
- **Assumes little** - the user may not have read the subject, and may see only the dialog. Give just enough context to decide: what the thing does and what is at stake
- **Stays neutral** - mark `(Recommended)`, with the reason, only where one option is strongly advisable
- **Shows its history** - revisiting a decision quotes it, from a report or the session, and says why it is back

Where `AskUserQuestion` is unavailable (a headless run, a subagent), write the questions and your lean on each under `Open` at the report path, then stop.

## 4. Close
Flag answers that conflict with each other, the standards, or research findings, and ask the user to resolve them.

State the conclusions in chat, then ask with a `multiSelect` `AskUserQuestion` for any of the following, carried out in this order:
- Write a report to the report path, in the format below
- Capture the conclusions in the project's documentation, naming the file in the option: the doc where the topic lives, and `CLAUDE.md` only for what every session needs
- Implement all conclusions now, without further confirmation

```
# Consult <subject>

## Decisions
- **<decision>** - <the value behind it>. <what it implies for implementation>

## Facts
- <what the user supplied that research could not>

## Open
- <question left unanswered, with your lean if the user never saw it>
```
