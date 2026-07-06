# Bash (sh)
- Assume Debian family distro
- Assume passwordless sudo
- Pass arguments as `--arg`
- Minimize env var reliance
- Never depend on the caller's `pwd`
- Keep console output terse
- Print status directly with `echo`/`printf`; don't wrap output in a logging helper function
- Start `.sh` files like so (omit `TOP_DIR` when the script doesn't need the repo root):
```sh
#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )
```
- Check required commands like so:
```sh
require_commands() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || { echo "Error: '$cmd' not found" >&2; exit 1; }
    done
}
```
- Update system packages like so:
```sh
apt_update() {
    sudo apt-get -qquy update --allow-releaseinfo-change
    sudo apt-get -qqf install
    sudo dpkg --configure -a
}
```
- Install packages like so:
```sh
apt_install() {
    sudo apt-get -qqfy install "$@"
}
```
- Parse `--arg`-style long options with a `while [[ $# -gt 0 ]]` / `case` loop (`shift 2` for value options, `shift` for flags); error and exit on unknown arguments
- Clean up temp files with `tmp_dir=$(mktemp -d)` and `trap 'rm -rf "$tmp_dir"' EXIT`
