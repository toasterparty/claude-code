# Project setup
Every green-field project gets a top-level Makefile as its application-developer interface: it normalizes details that vary project-to-project (language, framework, buildsystem) behind a few memorable, hand-typed targets. Treat it as living introductory documentation - keep it simple and free of clutter. Before writing it, read `languages/make.md` in the Claude home directory.
- Expose intent (`install`, `run`, `test`, ...), not implementation; hide the underlying commands behind targets.
- CI/CD invokes make targets, never the recipe commands directly - one source of truth for how the project builds, runs, and tests.
- This is a task runner, not a build graph: `make` runs the recipe every time and does not skip work when nothing changed. Delegate real incremental builds to the underlying buildsystem.

Reuse these target names across projects so the interface is predictable:
```sh
make install   # one-time project setup
make run       # run in the foreground (this shell)
make start     # start in the background (restart if already running)
make stop      # stop the backgrounded application, if running
make logs      # tail the backgrounded application's log, if running
make test      # non-mutating gate: format check, static analysis, unit + integration tests
make format    # apply formatting fixes in place (dev convenience; CI runs test, never this)
make upgrade   # bump all dependencies to latest
make clean     # erase all generated files
```
