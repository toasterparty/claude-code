#!/usr/bin/env bash
# Claims the next report name in <repo>/.agent/reports/, YYYYMMDD<seq>-<skill>[-<subject>].md, by
# creating the file with the front matter fields the script can supply, and prints its path.
# <seq> runs a..y, then za..zz, so names keep sorting in run order. A sequence letter counts as
# taken when any report of that day holds it, archived ones included, whatever its skill.
set -euo pipefail
shopt -s nullglob
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# The install scripts stamp the deployed commit into the Claude home. A checkout of the config repo
# has no stamp, and its reports leave the field out.
DEPLOYED_COMMIT_PATH="$SCRIPT_DIR/../../.deployed-commit"
LOCK_WAIT_TENTHS=50
SEQUENCES=({a..y} z{a..z})

usage() {
    echo "Usage: $0 --repo <path> --skill <name> [--subject <slug>]" >&2
    exit 2
}

take_lock() {
    local lock_dir=$1 i
    for ((i = 0; i < LOCK_WAIT_TENTHS; i++)); do
        mkdir "$lock_dir" 2>/dev/null && return
        sleep 0.1
    done
    echo "Error: lock '$lock_dir' still held after $((LOCK_WAIT_TENTHS / 10))s" >&2
    exit 1
}

find_free_sequence() {
    local reports_dir=$1 day=$2 seq
    for seq in "${SEQUENCES[@]}"; do
        local taken=("$reports_dir/$day$seq"-*.md "$reports_dir/_archive/$day$seq"-*.md)
        ((${#taken[@]})) || { echo "$seq"; return; }
    done
    echo "Error: every sequence for $day in '$reports_dir' is taken" >&2
    exit 1
}

fetch_commit() {
    local repo=$1 sha
    sha=$(git -C "$repo" rev-parse --short HEAD)
    [[ -z "$(git -C "$repo" status --porcelain -uno)" ]] || sha="$sha-dirty"
    echo "$sha"
}

repo=""
skill=""
subject=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) [[ $# -ge 2 ]] || usage; repo=$2; shift 2 ;;
        --skill) [[ $# -ge 2 ]] || usage; skill=$2; shift 2 ;;
        --subject) [[ $# -ge 2 ]] || usage; subject=$2; shift 2 ;;
        *) echo "Error: unknown argument '$1'" >&2; usage ;;
    esac
done
[[ -n "$repo" && -n "$skill" ]] || usage
slug_pattern='^[a-z0-9]+(-[a-z0-9]+)*$'
[[ "$skill" =~ $slug_pattern ]] || { echo "Error: --skill '$skill' is not a lowercase hyphenated slug" >&2; exit 2; }
[[ -z "$subject" || "$subject" =~ $slug_pattern ]] || { echo "Error: --subject '$subject' is not a lowercase hyphenated slug" >&2; exit 2; }

branch=$(git -C "$repo" branch --show-current)
commit=$(fetch_commit "$repo")
config=""
if [[ -r "$DEPLOYED_COMMIT_PATH" ]]; then
    config=$(head -c 7 "$DEPLOYED_COMMIT_PATH")
fi
reports_dir="$repo/.agent/reports"
mkdir -p "$reports_dir"

take_lock "$reports_dir/.new-report.lock"
trap 'rmdir "$reports_dir/.new-report.lock" 2>/dev/null || true' EXIT

date=$(date +%F)
day=${date//-/}
seq=$(find_free_sequence "$reports_dir" "$day")
path="$reports_dir/$day$seq-$skill${subject:+-$subject}.md"
{
    echo '---'
    echo "skill: $skill"
    echo "date: $date"
    echo "branch: ${branch:-detached}"
    echo "commit: $commit"
    [[ -z "$subject" ]] || echo "subject: $subject"
    [[ -z "$config" ]] || echo "config: $config"
    echo '---'
} > "$path"
echo "$path"
