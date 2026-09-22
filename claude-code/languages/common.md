# Common
Language-independent rules, read alongside the file for the language in hand.

- Guard clauses for edge cases; the success path sits unindented at the bottom
- `return`/`break`/`continue` over `else`
- Indent 1-3 levels; never 5+
- Small functions; standalone logic moves to a private function
- Validate input once, where it enters the process; inside, assert invariants rather than re-checking
- Every fallible call is checked, and its failure returned, asserted, logged, raised or remembered with what was being attempted. Discard a result only where failure is nominal - a `find` that comes up empty, a `try` variant the caller retries - or in teardown

## Verbs
One verb per meaning, never a synonym, so one function name tells the reader the shape of the rest. Casing and separators follow the language; the verb does not change.

| Verb | Means |
| --- | --- |
| `get`/`set` | a value already in memory: cheap, no allocation, no I/O, cannot fail |
| `fetch` | cross a boundary the process does not own - network, filesystem, peripheral - so slow and fallible |
| `resolve` | turn an indirect reference into the concrete value it names, pure or boundary-crossing |
| `calc` | derive from the arguments alone; reads and writes no state |
| `find` | a search that may legitimately come up empty, where `get` presumes existence |
| `is`/`has`/`can` | boolean question, no side effects |
| `check` | report a bool, a status, or a log line, without rejecting or fixing anything - `validate`'s soft sibling |
| `validate` | reject bad input by raising or returning an error, never a bool |
| `ensure` | idempotent check-before-act: make the condition true, or return because it already is |
| `sync` | reconcile two stores to matching state, bidirectional - `load`/`save` move in one direction only |
| `try` | prefix for the variant that reports failure to the caller instead of aborting: `try_take`, `try_fetch` |
| `to`/`as` | convert: `as` views the same data, `to` builds a copy |
| `build` | assemble a compound value from several inputs, where no single one converts directly |
| `poll`/`wait` | `poll` returns at once with what is ready; `wait` blocks until it is |
| `on` | prefix for a handler something else invokes on an event; never for a function the code calls directly |

Setup pairs with exactly one teardown, and the pairing is the signal: `init` is undone by `deinit`, never `free`; a reader who sees `open` looks for `close`.

| Pair | Applies to |
| --- | --- |
| `alloc`/`free` | memory |
| `init`/`deinit` | storage the caller already owns, to usable and back |
| `create`/`destroy` | whole-object lifetime where the language hides the allocation |
| `open`/`close` | a handle on something outside the process: file, socket, device |
| `connect`/`disconnect` | a session with a peer |
| `take`/`give` | exclusive hold of a mutex, semaphore, or bus; never `acquire`/`release` or `lock`/`unlock`. Hold across the smallest block that needs it, never across I/O or a callback |
| `register`/`unregister` | an entry in a table someone else owns, typically a callback |
| `subscribe`/`unsubscribe` | an ongoing stream of events |
| `enable`/`disable` | a capability that stays configured while off |
| `start`/`stop`, `pause`/`resume` | an activity that runs on its own |
| `push`/`pop`, `add`/`remove` | membership in a collection |
| `load`/`save` | a local persistent store |
| `read`/`write`, `send`/`recv` | bytes through an open handle; messages over a connection |
| `encode`/`decode`, `parse`/`format` | a representation crossing in and out of the type system |

Never `do`, `handle`, `process`, `manage`, `perform`: a category, not an effect. A verb an external spec defines - `http_post`, `i2c_probe` - keeps the spec's name. Otherwise, when no verb fits, the function is doing more than one thing.

## Nouns
- `cb` suffix on a parameter, field, or variable that holds a function to be called later: `done_cb`. The function stored there is the `on` handler: `register(on_done)` lands in `done_cb`
- Units in the name wherever a bare number is ambiguous: `timeout_ms`, `len_bytes`, `heading_deg`
- `len` counts elements, `size` counts bytes, `count` counts occurrences; `idx` is a position, `id` an identity
- Plural for a collection, singular for one of its elements
- A boolean reads as a predicate - `is_ready`, `has_data` - never `ready_flag` or `status`
- A literal other than 0 or 1 gets a name unless the call site already says what it is
- Name length scales with scope: `i` in a loop and `data` in a short function are fine because the surrounding code says what they are; a symbol read far from its definition carries its meaning in full

## Best-effort teardown
Teardown - `free`, `deinit`, `destroy`, `close`, `give`, `stop`, `disconnect`, `unregister`, `cancel`, `reset` - returns nothing and reports nothing: it swallows what it cannot fix and logs at most. A fallible teardown has no answer to a cleanup path whose own cleanup fails, and that path is already running because something else went wrong.
- Accept every state, partly constructed or already torn down; teardown of an empty handle is a no-op, so a caller unwinds from any point without tracking how far setup got
- Where teardown does work whose failure the caller must act on - flushing writes, committing a transaction - split it: a fallible `flush` or `commit` the caller may run first, and an infallible `close` that still flushes best effort
