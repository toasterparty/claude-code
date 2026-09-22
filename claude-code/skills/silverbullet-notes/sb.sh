#!/usr/bin/env bash
# The SilverBullet CLI with its saved spaces kept per Claude home, installed on first use.
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
RELEASE_URL=https://github.com/silverbulletmd/silverbullet/releases/latest/download

install_sb() (
    case "$(uname -s)" in
        Linux) os=linux ;;
        Darwin) os=darwin ;;
        MINGW* | MSYS* | CYGWIN*) os=windows ;;
        *) echo "Error: unsupported OS '$(uname -s)'" >&2; exit 1 ;;
    esac
    case "$(uname -m)" in
        arm64) arch=aarch64 ;;
        armv7l) arch=armv7 ;;
        *) arch=$(uname -m) ;;
    esac
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT
    curl -fsSL -o "$tmp_dir/sb.zip" "$RELEASE_URL/sb-$os-$arch.zip"
    mkdir -p "$BIN_DIR"
    unzip -oq "$tmp_dir/sb.zip" -d "$BIN_DIR"
    echo "Installed sb into $BIN_DIR" >&2
)

sb=$(command -v sb || echo "$BIN_DIR/sb")
[[ -x "$sb" ]] || install_sb

XDG_CONFIG_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" exec "$sb" "$@"
