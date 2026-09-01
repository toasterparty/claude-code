# Tests
Applies in every language; read alongside the file for the language under test.
- A test discloses behavior as much as it guards against regression. Write it to be read cold, by someone who has not read the implementation
- Prefer a named example - one concrete input and its expected result, both visible in the test body - to a parametrized sweep over cases no reader can name
- Name a test for the behavior it pins, so a failure reads as a sentence describing what broke
- Assert the contract the interface declares, through its signature, its documentation, or its docstrings. A test that knows a private attribute, an internal call order, or an intermediate value was written against the implementation, and it breaks on refactors that change nothing observable. This is the most common mistake
- Where the behavior worth asserting is not declared anywhere, declare it first, then assert it
- Assert the exact value wherever it is knowable - `is not None`, a length check, a type check all pass against broken code
- The expected result is a literal, never recomputed by the code under test or by a reimplementation of it
- Deterministic: seed randomness, freeze time, no sleeps, no real network - a test that can fail without a code change teaches nothing
- Mock only at boundaries the project does not own - the clock, the network, the filesystem. A mock of the project's own module pins the very implementation detail the contract rule forbids
- Delete a test whose functional coverage another test already provides. A test earns its keep by being the one thing that would catch a given regression
- Refactor boilerplate into fixtures and helpers - never the input or the expected result, which stay in the test body
