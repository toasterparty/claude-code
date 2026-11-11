# Progressive disclosure
Layer instructions and docs so each reader pays only for the depth their task needs.
- The always-loaded layer (a `CLAUDE.md`, a skill's description, a README) holds what every reader needs, plus a trigger for each deeper file: when to read it, never a summary of it.
- A deeper file loads only on its trigger and never restates the layer above it. A one-line pointer to a still-deeper file, on its own trigger, is not a restatement.
- Within a file, the common case comes first and detail follows in order of how few readers need it.

## Instructions an agent follows
A rule in a `CLAUDE.md`, a skill, or a guidance file is judged by the behavior it changes, never by its length. It is exempt from the Concise+ rule on length and from Rhythm, because one misread or one blocked tool call costs more than the words that would have prevented it.
- Write the rule so the reader can act on it without decoding it. Where a compressed phrasing and a plain one differ in length, take the plain one.
- Follow the rule with its reason wherever the reason is not obvious. A reader who knows the reason applies the rule correctly to cases it never named, and a later editor can tell whether the rule still earns its place.
- Give one example where the boundary of the rule is unclear.
- Where a hook enforces a policy, state the instruction in the hook's own terms and scope, and put the remedy in the hook's denial message. An instruction narrower than its hook invites the calls the hook then blocks.
- Change an instruction on evidence of what agents did (a denial log, a transcript, a user correction) in preference to a reading of its wording.
