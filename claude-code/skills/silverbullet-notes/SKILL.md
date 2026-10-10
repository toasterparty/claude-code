---
name: silverbullet-notes
description: Read, search, write, query, or script the user's SilverBullet notes at notes.toasterparty.net. Use when the user mentions their notes, a notes space, or SilverBullet, or asks to look something up in or save something to their notes.
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/sb.sh *)
---

# SilverBullet notes

SilverBullet is a self-hosted, programmable markdown notes app. A space is a folder of markdown files: the page `Projects/Example` is the file `Projects/Example.md`. Pages carry YAML frontmatter, `[[wikilinks]]`, `#tags`, and `- [ ]` tasks, all indexed as queryable objects. Space Lua makes the space programmable: `space-lua` fenced blocks define functions and commands active across the whole space, `${expr}` renders inline, `query[[...]]` runs queries over the index, and `CONFIG.md` configures the space. A `space-lua` block written to a page is code that runs in every client opening the space.

The server `https://notes.toasterparty.net` hosts several spaces, one per path prefix. Its data folder is `~/git/toaster-server/services/silver-bullet/data/` on `toaster@toasterparty.net`, reached over SSH or read directly when the session runs on the server itself. There `spaces.json` maps each space's `binding.prefix` to its `folder` and anonymous `access`.

## Tool
Use the official SilverBullet CLI through `bash ${CLAUDE_SKILL_DIR}/sb.sh`, written `sb` below; never run a bare `sb`. The wrapper installs the CLI on first use and keeps its saved spaces and encrypted credentials in `<claude home>/silverbullet/`, so each Claude home has its own set. `sb --help` and `sb <command> --help` are authoritative where this file disagrees. Never use WebFetch on the notes: it summarizes content and cannot write.

## Scope
`sb space ls` is the only record of which spaces this skill may touch. Never read or write a space missing from it, over SSH included. A request naming no space covers every saved one. Never ask for a token in chat or store one anywhere else.

When `sb space ls` lists no space on this server, or a request names an unsaved one, follow `setup.md` beside this file before anything else.

Exit code 4 or `authentication_required` means the login is missing or expired: run `sb space login <name> --no-browser` in the background. It prints a confirmation code and link: relay both to the user, and the command exits once they approve. Then retry. Reading an anonymous-read space needs no login, but writing to it does.

## Files
Plain HTTP, no Runtime API needed. Paths are space-relative and include `.md`.
```sh
sb fs ls -s <name> --recursive --glob '*.md'
sb fs read -s <name> 'Projects/Example.md'
sb fs write -s <name> 'Projects/Example.md' --create --file draft.md
sb fs edit -s <name> 'Projects/Example.md' --old='- [ ] Ship it' --new='- [x] Ship it'
sb fs rm -s <name> 'Projects/Example.md' --if-match '<revision>'
```
- Join values to their flag with `=`, as above. A value starting with `-`, as every markdown bullet does, otherwise parses as a flag.
- `fs ls` prints one JSON line that includes the read-only `Library/` and `Repositories/` pages, so filter `entries[].path` with `jq` or `python3`, never `grep`.
- Draft page content and multi-line scripts with the Write tool into a temp file, then pass it by `--file` or run it with `python3`. A Bash heredoc whose prose names a git command trips the hook that reserves git for the user.
- Write wikilinks from the space root, like `[[ideas/facere/design]]`. Whether a bare `[[game-engine/editor]]` resolves from the linking page's folder or from the root is unverified, and a wrong guess creates a stray page.

Prefer `edit` for changes, since it writes conditionally against its own read. A full rewrite passes `--if-match` the `revision` from `sb fs stat --json`, embedded quotes included (`'"sha256:..."'`); `--overwrite` only when the user asks to clobber. Exit 5 means the page changed since it was read, or already exists under `--create`: reread before deciding what to write.

## Queries and Lua
These run in a headless client on the server with the full Space Lua API (`space.*`, `editor.*`, `index.*`, queries). The first call per space is slow while it boots. A 403 or 503 means the Runtime API is unavailable for that space: fall back to files or SSH.
```sh
sb describe -s <name> --text
sb query -s <name> 'from p = index.pages() order by p.lastModified desc limit 5 select p.name' --json
sb eval -s <name> 'query[[from t = index.tasks() where not t.done select t.ref]]' --json
sb script -s <name> --file script.lua
```
`sb describe --text` lists the queryable types and query syntax, and `sb describe <type> --text` one type's fields; without `--text` it dumps every schema as JSON. An empty result is not proof of absence: a misnamed field matches nothing without an error. For the rest of the API, the docs are raw markdown at `https://silverbullet.md/.fs/<Page>.md` (`API.md`, `Space%20Lua.md`, `HTTP%20API.md`); fetch them with `curl`, since the rendered site is a client-side app.

`eval` takes one expression; anything with statements or `return` goes through `script --file`.

Before changing or debugging a space's behavior (`CONFIG.md`, `space-lua`, `space-style`, key bindings, panels), read `config.md` beside this file.

## SSH
`sb fs` has no content search. To grep or bulk-read a saved space, run the search over SSH inside that space's `folder` from `spaces.json`. Treat it as read-only: SSH writes skip the conflict checks `sb` applies.
