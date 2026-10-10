# Adding a space
1. Read the space names and prefixes from `spaces.json` over SSH. If SSH fails, ask the user for the space URLs.
2. Ask with `AskUserQuestion` (`multiSelect`, split across questions past four options) which spaces the skill should use.
3. Add each chosen space with `printf '<prefix>\nhttps://notes.toasterparty.net/<prefix>\nbrowser\n' | sb space add --no-browser`, run in the background, relaying its confirmation code and link as for `sb space login`. A space with anonymous access finishes without sign-in.
