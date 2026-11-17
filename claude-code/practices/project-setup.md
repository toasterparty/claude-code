# Project setup
Design every repo for a new developer on a freshly installed OS that has only git and the default shell (bash on Linux and macOS, PowerShell on Windows). Count every step on their path from `git clone` to a running project, and cut steps until only the unavoidable remain: typically one bootstrap that puts `make` on the machine, then `make install`. Any other prerequisite (a language runtime, a package manager, a compiler) is installed by the project's own idempotent script, never by README prose the developer has to follow by hand, because prose steps drift out of date and get skipped.

## Layout
Create each entry only once it has real content. Never scaffold a placeholder file, an empty directory, a `.gitkeep`, or a stub doc, because an empty slot tells the reader nothing and goes stale unnoticed.
```
README.md                      what it is, how to install and run it
Makefile                       the developer interface
tools/*.sh, tools/*.ps1        scripts too long for a Makefile recipe
build/                         every generated file, ignored by its own .gitignore
doc/user/*.md                  using the project
doc/maintainer/*.md            working on the project
doc/maintainer/references.md   related repositories and more
.vscode/extensions.json        recommended editor extensions
.agent/AGENTS.md               agent instructions, untracked
```

## Docs
- Keep `README.md` minimal, as `practices/artifacts.md` describes. Anything longer moves to `doc/user/` or `doc/maintainer/`, with a link from the README.
- `doc/maintainer/references.md` lists the repositories this one relates to, created once the first one exists. It is the first place an agent looks for what it can clone into `.agent/git/` to answer a question about another repo, such as how a client calls this server's API, so every row carries the exact clone URL:

| Repository | Clone URL | Relationship |
| --- | --- | --- |
| `app-client` | `https://github.com/org/app-client.git` | Calls this server's REST API |

- Agent instructions go in an untracked `.agent/AGENTS.md`, not a tracked root `AGENTS.md`. Starting a green-field project counts as the user asking for it. Keep it to references: each line names a tracked doc under `doc/` and when to read it, plus the few facts only an agent needs. Knowledge a human maintainer would also need goes in the tracked doc, so one copy serves both readers and none drifts.

## Ignore files
- Ignore only what the project actually generates, never a template's boilerplate list.
- Prefer several small `.gitignore` files, each in the directory whose contents it ignores, over one broad root file: a scoped file cannot accidentally hide a same-named file elsewhere in the tree, and it moves or disappears with its directory.
- `build/` ignores itself: the recipe that creates it also writes `build/.gitignore` containing `*`, so the root needs no entry.
- In `.vscode/`, track only `extensions.json`, the recommended extensions every developer should get. Settings, launch configs, and everything else are per-developer and stay untracked through `.vscode/.gitignore`:
```
*
!.gitignore
!extensions.json
```

## Makefile
Every project gets a top-level Makefile as its developer interface: a few memorable, hand-typed targets that hide the language, framework, and buildsystem. Keep it simple enough to read as introductory documentation. Before writing it, read `languages/make.md`.
- Targets expose intent (`install`, `run`, `test`, ...), not implementation.
- CI/CD invokes make targets, never the recipe commands directly.
- `make install` is idempotent: rerunning it on a set-up machine changes nothing, and rerunning it on a half-set-up one finishes the job.

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
