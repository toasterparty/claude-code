# Mine the session history
Script the work past sessions did by hand.

Transcripts live at `<claude home>/projects/<repo path with every separator and colon replaced by `-`>/<session-id>.jsonl`, with subagent transcripts in a sidecar directory named for the session. `<claude home>` is `$CLAUDE_CONFIG_DIR` when set, otherwise `~/.claude`.

Opus and above delegate the skim to an Explore subagent, handing it the exact files and byte offsets from the ledger. Filter the JSONL down to user messages and tool-call inputs before reading. Collect only each procedure, the commands that carried it out, and the arguments a script would take.

Worth a script: a multi-command procedure repeated across sessions or rebuilt each time, an invocation that took several attempts (quoting, platform differences, pagination, auth), anything the user had to correct. Not worth one: anything a single tool call solves.

Write each new script under the same rules as the generalized ones in step 5: argument-driven, idempotent, non-interactive, no repo-specific path.

## Skim ledger
Never skim the same bytes twice. The ledger is `scripts/data/tidy/skimmed.tsv`: one line per transcript, `<session-id>`, tab, its size in bytes when skimmed. List the transcript directory with sizes and compare:

- absent, or smaller than recorded (rotated) - skim the whole file
- larger - skim only the tail, from `tail -c +<recorded + 1>`
- equal - skip without opening

Record sizes from that listing, never from a fresh stat after the skim, so bytes appended mid-run (the tidying session's own transcript among them) are picked up next time.

A first run against a long history is the expensive one. Work newest-first, stop when findings dry up, and record only what was skimmed, leaving the rest pending.
