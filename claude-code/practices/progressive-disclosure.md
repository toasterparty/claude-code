# Progressive disclosure
Layer instructions and docs so each reader pays only for the depth their task needs.
- The always-loaded layer (a `CLAUDE.md`, a skill's description, a README) holds what every reader needs, plus a trigger for each deeper file: when to read it, never a summary of it.
- A deeper file loads only on its trigger and never restates the layer above it. A one-line pointer to a still-deeper file, on its own trigger, is not a restatement.
- Within a file, the common case comes first and detail follows in order of how few readers need it.
