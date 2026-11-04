# Failures

## Failure messages
An error, warning, or failure message states the facts of the failure - what was attempted, on what, and what happened - at the detail its reader needs. It never prescribes a fix: the right remedy depends on a context the program cannot see, so it has neither the knowledge nor the authority to direct the reader.
- `git: not found on PATH`, never `Install git and try again`
- `config.toml: line 12: cannot open 'certs/ca.pem'`, never `Check your config`

A remedy belongs in the message only where the emitter does know it:
- The failure is the absence of a user action: `Not signed in. Sign in at https://example.com/device with code ABCD-1234`
- The emitter owns the policy the reader broke, as a permission hook does for the agent it constrains
- A deprecation names its successor; a typo names its nearest valid match (`did you mean 'timeout'?`)

The rule governs message text, not affordances: a UI may still offer Retry or Sign in beside the facts. It binds shipped software, not an agent's report to its user, which is written with the context the rule says a program lacks.

## Best-effort teardown
Teardown - `free`, `deinit`, `destroy`, `close`, `give`, `stop`, `disconnect`, `unregister`, `cancel`, `reset` - returns nothing and reports nothing: it swallows what it cannot fix and logs at most. A fallible teardown has no answer to a cleanup path whose own cleanup fails, and that path is already running because something else went wrong.
- Accept every state, partly constructed or already torn down; teardown of an empty handle is a no-op, so a caller unwinds from any point without tracking how far setup got
- Where teardown does work whose failure the caller must act on - flushing writes, committing a transaction - split it: a fallible `flush` or `commit` the caller may run first, and an infallible `close` that still flushes best effort
