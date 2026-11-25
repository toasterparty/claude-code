---
name: consult
description: Interview the user for the decisions, values, judgments, rankings, and undiscoverable facts that should steer a subject. Use at a contestable decision costly to reverse, or when the user takes a bird's-eye view or is reinforcing a plan, concept, or design before implementing it. Never during an unattended plan run.
argument-hint: "[subject]"
---

# Consult

Sessions narrow: agents silently rule out alternatives. The aim is enough bird's-eye guidance that the user is satisfied with the outcome without nitpicking its implementation.

Every consult writes a report, under `practices/reports.md`: start it once the subject is resolved, with `--skill consult` and a `--subject` slug for the subject. The report serves later sessions, not the user: never mention it in chat or in a question.

## 1. Subject
Subject given with the invocation is used as-is. Invoking the skill yourself, name the subject from the decision at hand. Otherwise resolve it with a `multiSelect` `AskUserQuestion`, naming each option concretely and omitting empty ones, or pick the likeliest subject where the tool is unavailable:
- The current session topic, or a related one
- Recent git activity: uncommitted changes, recent commits, or the branch diff against the default branch
- The project as a whole
- A specific plan, requirements set, or design

## 2. Research
Read the subject, the standards that govern it, and earlier consult reports on it in `.agent/reports/` and its archive, where on conflict the newest wins. Stop once more reading would not change the questions. Look for:
- Contradictions: a plan against the implementation, a doc against the code, one requirement against another, anything against the standards. Each becomes a question unless evidence settles it
- Decisions already made, by anyone: everything is open to challenge, including the user's own decisions, plans, and standards
- Alternatives the conversation never considered, and framings a reasonable person would reject
- Facts only the user can supply
- Where the subject is a change (a diff, commit, branch, or PR): each place its design or intent may conflict with a value the user holds. The answers turn these into review findings, which Step 4 can write out

Then cut any value question two reasonable people would not disagree on, any candidate research can answer or whose answer would not change the outcome, and any agent-owned decision as `practices/decisions.md` defines it. Decide those yourself. Check each factual premise a remaining question rests on against the code or data, as `practices/decisions.md` requires.

## 3. Ask
Ask in rounds of up to four questions, most consequential first. Let answers spawn follow-ups and retire questions. Stop when nothing left would change the outcome, or when the user says to. An answer through `Other` can redefine the question: follow what it says. To rank, pit the top contenders against each other or invite an ordering through `Other`, since the tool has no ranking input.

Each question:
- **Probes a value, unless asking a fact** - implementation is secondary. Not "Redis or an in-process cache?" but "Is losing cached state on restart acceptable to avoid running another service?", with the implementations in the option descriptions
- **Holds one decision** - never bundle unrelated decisions into one `multiSelect` where leaving a box unchecked means "change it", because an unchecked box cannot say whether the user rejected the choice or skipped it
- **Stays neutral** - mark `(Recommended)`, with the reason, only where one option is strongly advisable
- **Shows its history** - revisiting a decision quotes it, from a report or the session, and says why it is back

Where `AskUserQuestion` is unavailable (a headless run, a subagent), close the run as `Closing a run` in `practices/reports.md` describes, opening one item per question, tagged `User Decision`, and writing each question with your lean on it under `Open` in the report body Step 4 gives. Then stop. A subagent returns those items to its parent session instead of adding them, as that section says.

## 4. Close
Flag answers that conflict with each other, the standards, or research findings, and ask the user to resolve them.

State the conclusions in chat, then ask with a `multiSelect` `AskUserQuestion` for any of the following that apply, carried out in this order. Each option's description says only what choosing it does. The agenda update below happens whatever the user picks, so it is never an option and never an option's description:
- Capture the conclusions in the project's documentation, naming the file in the option: the doc where the topic lives, and `AGENTS.md` only for what every session needs
- Implement all conclusions now, without further confirmation. Offer it only where some conclusion asks for work
- Write the review findings to `.agent/outbox/review-<subject>-<YYYY-MM-DD>.md`. Offer it only where the subject is a change and the interview left findings against it

The review file holds one comment per finding, most consequential first, each paired with the one line range of the change's new side that best demonstrates it. Word each comment as a reviewer posting it on a PR: what the code does, the value it works against, and the change asked for, with no reference to this consult, since the user may paste it into a review as written.

```
# Review <subject>

1. `path/to/file.py:40-52` - <comment>
```

Then close the run as `Closing a run` in `practices/reports.md` describes. It opens one item for each question left open, tagged `User Decision`, and one for the conclusions not yet implemented, and removes any item asking for this subject to be consulted. The body after the front matter is:

```
# Consult <subject>

## Decisions
- **<decision>** - <the value behind it>. <what it implies for implementation>
    - > <the user's words, verbatim, wherever they typed the answer rather than picked an option>

## Facts
- <what the user supplied that research could not>

## Open
- #<id> <question left unanswered, with your lean if the user never saw it>
```

## Called by another skill
Another skill may hand you decisions to put to the user, because its own questions would carry too little context. The caller owns the work the decisions steer, so it implements them, records them, and tracks them on the agenda. Run steps 1 to 3 and the conflict check of step 4 as usual, offering any extra options the caller asks for, such as `Skip for now`. Then skip the rest of step 4: state the conclusions in chat, complete the report with `opened` and `closed` empty, archive it, and return to the caller each decision with the item ID it settles, and each question left unanswered.
