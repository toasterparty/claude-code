# Project setup
Every green-field project gets a top-level Makefile as its developer interface: a few memorable, hand-typed targets that hide the language, framework, and buildsystem. Keep it simple enough to read as introductory documentation. Before writing it, read `languages/make.md`.
- Targets expose intent (`install`, `run`, `test`, ...), not implementation.
- CI/CD invokes make targets, never the recipe commands directly.

Use these target names:
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
