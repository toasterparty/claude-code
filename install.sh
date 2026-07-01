#!/usr/bin/env bash
# Install/upgrade Claude Code and deploy this repo's config into ~/.claude.
set -euo pipefail

REPO_ARCHIVE="https://github.com/toasterparty/claude-code/archive/refs/heads/main.tar.gz"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
TMP_DIR=""
SRC=""

log() { printf '==> %s\n' "$*" >&2; }
cleanup() { [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Fail fast if any external command this script depends on is missing.
check_requirements() {
    local missing=() cmd
    for cmd in curl tar jq; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ "${#missing[@]}" -ne 0 ]; then
        log "ERROR: missing required command(s): ${missing[*]}"
        log "       Install them and re-run (apt-get install <cmd> / brew install <cmd>)."
        exit 1
    fi
}

install_claude_code() {
    if command -v claude >/dev/null 2>&1; then
        log "Updating Claude Code"
        claude update
    else
        log "Installing Claude Code"
        curl -fsSL https://claude.ai/install.sh | bash
    fi
}

# Download the repo and set SRC to the config directory within it.
resolve_source() {
    log "Downloading config from $REPO_ARCHIVE"
    TMP_DIR="$(mktemp -d)"
    curl -fsSL "$REPO_ARCHIVE" | tar -xz -C "$TMP_DIR"
    SRC="$TMP_DIR/claude-code-main/claude-code"
}

# Enforce the keys from the tracked settings.json onto the user's existing file,
# preserving any keys the user set that we don't specify.
merge_settings() {
    local tracked="$1" target="$2"
    [ -f "$tracked" ] || return 0
    local current='{}' tmp_out
    [ -f "$target" ] && current="$(cat "$target")"
    tmp_out="$(mktemp)"
    if jq -s '.[0] * .[1]' <(printf '%s' "$current") "$tracked" >"$tmp_out"; then
        mv "$tmp_out" "$target"
    else
        rm -f "$tmp_out"
        log "WARNING: could not parse existing settings.json; left it untouched."
    fi
}

# Replace each top-level entry of $CLAUDE_DIR that this repo owns with a fresh copy from $src,
# so entries removed from $src (e.g. a deleted languages/*.md) don't linger in $CLAUDE_DIR.
sync_config() {
    local src="$1" f name dest
    log "Deploying config into $CLAUDE_DIR"
    mkdir -p "$CLAUDE_DIR"
    while IFS= read -r -d '' f; do
        name="$(basename "$f")"
        [ "$name" = "settings.json" ] && continue
        dest="$CLAUDE_DIR/$name"
        rm -rf "$dest"
        cp -rf "$f" "$dest"
    done < <(find "$src" -mindepth 1 -maxdepth 1 -print0)
    merge_settings "$src/settings.json" "$CLAUDE_DIR/settings.json"
}

check_requirements
install_claude_code
resolve_source
sync_config "$SRC"
log "Done."
