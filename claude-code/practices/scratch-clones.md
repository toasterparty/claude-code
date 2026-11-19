# Scratch clones
A scratch clone lives in `<repo>/.agent/git/<name>/`. It is yours: every local git command is allowed there and nothing in it needs preserving.

Use a clone, never `git worktree add`, even for another branch of the same repo. A worktree writes refs and metadata into the user's `.git`, which the user then has to review. A clone touches nothing of theirs.

## Creating
- Name the clone `<repo>-<ref>`, such as `server-main` or `server-pr-123`, so two refs of one repo never collide and a later session can tell what is checked out without inspecting it.
- Clone from the origin URL (`git remote get-url origin`) for remote branches and PRs, the repo path for local-only ones, and the URL listed in the repo's docs for a related repository, starting with `doc/maintainer/references.md` where it exists.
- Clone shallow: `--depth 1`, plus `--branch <ref>` when known. A local source path needs a `file://` URL for `--depth` to apply. Deepen only when a question needs history.
- Use `--filter=blob:none` instead when the question spans history or many refs (blame, log, bisect).
- Add `--recurse-submodules --shallow-submodules` when the clone has to build.
- A GitHub PR has no branch to pass to `--branch`. Clone the default branch shallow, then `git -C .agent/git/<name> fetch --depth 1 origin pull/<n>/head` and `git -C .agent/git/<name> switch --detach FETCH_HEAD`. GitLab names the ref `merge-requests/<n>/head`.

## Using
- Run every git write as `git -C .agent/git/<name> <command>` with no other option. The hook recognizes only that form, so `cd .agent/git/<name> && git checkout x` is still denied.
- Before reading an existing clone, `fetch --tags` and then `reset --hard @{u}`, so no decision rests on an outdated commit. Prefer the reset to `pull`, which can refuse to merge in a shallow clone, because nothing in the clone needs preserving.

## Lifetime
A clone of a related repository on its default branch persists across sessions, because later tasks keep asking about the same client or library. Every other clone, of this repo or of another repo at a branch or PR, is task-scoped: `rm -rf` it once the task stops needing it. `/tidy` purges task-scoped clones and spares persistent ones.
