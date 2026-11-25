#!/usr/bin/env bash
# Removes one agenda item with all the bookkeeping a removal needs, under the lock next-id.sh takes:
# drops its line and sub-bullets, logs it in agenda-log.md, clears its ID from every `blocked by`
# tag, dates its section heading today, and archives each report whose `opened` IDs are all logged.
# Prints one line per action. A split section's top item, repeated in agenda/index.md, counts as one
# item, and the index copy gives way to the section's new top item. An ID that opens no item, or more
# than one otherwise, is an error that changes nothing.
set -euo pipefail
shopt -s nullglob
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/../lock.sh"

TRAILING_TAG_PATTERN=' +`(User Task|User Decision|blocked by [^`]*|blocked: [^`]*|open @[^`]*|Fable|Opus|Sonnet)`$'
# Spelled out, since mawk has no {n} interval
HEADING_DATE_REGEX=' - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$'

usage() {
    echo "Usage: $0 --repo <path> --id <n> --status resolved|dropped --evidence <text>" >&2
    exit 2
}

find_item_line_nos() {
    awk -v prefix="- #$2 " 'index($0, prefix) == 1 { print NR }' "$1"
}

# Prints the undated heading of the section holding a line, or nothing for a line above every heading.
fetch_heading() {
    awk -v item_line_no="$2" -v date_regex="$HEADING_DATE_REGEX" '
        NR >= item_line_no { exit }
        /^## / { heading = $0 }
        END { sub(date_regex, "", heading); if (heading != "") print heading }
    ' "$1"
}

is_section_file() {
    [[ "$1" == "$doc_dir"/agenda/* && "$1" != "$index_file" ]]
}

# Where the two matches are a split section's top item and its copy in agenda/index.md under the
# same heading, prints which of them is the copy.
find_index_mirror() {
    local mirror_idx item_idx heading
    for mirror_idx in 0 1; do
        item_idx=$((1 - mirror_idx))
        [[ "${match_files[mirror_idx]}" == "$index_file" ]] && is_section_file "${match_files[item_idx]}" || continue
        heading=$(fetch_heading "${match_files[item_idx]}" "${match_line_nos[item_idx]}")
        [[ -n "$heading" && "$heading" == "$(fetch_heading "$index_file" "${match_line_nos[mirror_idx]}")" ]] || continue
        echo "$mirror_idx"
        return 0
    done
    return 1
}

find_top_item() {
    awk '/^- #[0-9]+ / { print; exit }' "$1"
}

calc_headline() {
    local headline=${1#"- #$2 "}
    while [[ $headline =~ $TRAILING_TAG_PATTERN ]]; do
        headline=${headline%"${BASH_REMATCH[0]}"}
    done
    printf '%s\n' "${headline%.}"
}

# Each rewrite below reads <in>, writes <out>, and prints its actions naming the file <name>. Paths
# and agenda text reach awk through ENVIRON, since -v would expand the backslash escapes in them.
# A non-empty <replacement> line takes the place of the item and its sub-bullets.
remove_item() {
    out=$2 name=$3 replacement=${6:-} awk -v item_line_no="$4" -v id="$5" '
        BEGIN { out = ENVIRON["out"]; replacement = ENVIRON["replacement"] }
        NR == item_line_no {
            skipping = 1
            if (replacement != "") print replacement > out
            next
        }
        skipping && /^[ \t]+[^ \t]/ { sub_bullet_count++; next }
        { skipping = 0; print > out }
        END {
            if (replacement == "") {
                printf "removed #%s and %d sub-bullet lines from %s\n", id, sub_bullet_count, ENVIRON["name"]
                exit
            }
            match(replacement, /^- #[0-9]+/)
            printf "replaced #%s in %s with the new top item %s\n", id, ENVIRON["name"], substr(replacement, 3, RLENGTH - 2)
        }
    ' "$1"
}

date_heading() {
    out=$2 name=$3 heading=$4 awk -v today="$5" -v date_regex="$HEADING_DATE_REGEX" '
        BEGIN { out = ENVIRON["out"] }
        /^## / {
            base = $0
            sub(date_regex, "", base)
            if (base == ENVIRON["heading"]) {
                print base " - " today > out
                printf "dated \"%s\" %s in %s\n", base, today, ENVIRON["name"]
                next
            }
        }
        { print > out }
    ' "$1"
}

clear_blocker() {
    out=$2 name=$3 awk -v id="$4" '
        BEGIN { out = ENVIRON["out"]; target = "#" id; prefix_len = length("`blocked by ") }
        {
            rest = $0
            line = ""
            changed = 0
            while (match(rest, /`blocked by [^`]*`/)) {
                tag = substr(rest, RSTART, RLENGTH)
                before = substr(rest, 1, RSTART - 1)
                rest = substr(rest, RSTART + RLENGTH)
                n = split(substr(tag, prefix_len + 1, length(tag) - prefix_len - 1), entries, /, */)
                kept = ""
                removed = 0
                for (i = 1; i <= n; i++) {
                    if (entries[i] == target) { removed = 1; continue }
                    kept = kept (kept == "" ? "" : ", ") entries[i]
                }
                if (!removed) { line = line before tag; continue }
                changed = 1
                if (kept == "") { sub(/ +$/, "", before); line = line before }
                else line = line before "`blocked by " kept "`"
            }
            line = line rest
            print line > out
            if (!changed) next
            item = "a line"
            if (match(line, /^[ \t]*- #[0-9]+ /)) {
                item = substr(line, RSTART, RLENGTH)
                sub(/^[ \t]*- /, "", item)
                sub(/ $/, "", item)
            }
            printf "cleared %s from the blocked by tag of %s in %s\n", target, item, ENVIRON["name"]
        }
    ' "$1"
}

# Applies a rewrite to the staged copy of <file>, staging it on first use.
rewrite_staged() {
    local file=$1 rewrite=$2
    shift 2
    if [[ -z "${staged[$file]:-}" ]]; then
        staged[$file]="$tmp_dir/${#staged[@]}"
        cp -- "$file" "${staged[$file]}"
    fi
    # awk creates <out> only on its first print, and a rewrite may print no line
    : > "${staged[$file]}.new"
    "$rewrite" "${staged[$file]}" "${staged[$file]}.new" "${file#"$doc_dir/"}" "$@" >> "$actions"
    mv -f -- "${staged[$file]}.new" "${staged[$file]}"
}

list_logged_ids() {
    awk '/^- / && $2 ~ /^[0-9]+-[0-9]+-[0-9]+$/ && $3 ~ /^#[0-9]+$/ { print substr($3, 2) }' "$1"
}

fetch_opened_ids() {
    awk '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        /^opened:/ { sub(/^opened:[ \t]*\[/, ""); sub(/\].*$/, ""); gsub(/[ \t#]/, ""); print; exit }
    ' "$1"
}

archive_closed_reports() {
    local reports_dir=$1 log_path=$2 report opened target id
    local -A logged=()
    while read -r id; do logged[$id]=1; done < <(list_logged_ids "$log_path")
    for report in "$reports_dir"/*.md; do
        opened=$(fetch_opened_ids "$report")
        [[ -n "$opened" ]] || continue
        for id in ${opened//,/ }; do
            [[ -v "logged[$id]" ]] || continue 2
        done
        target="$reports_dir/_archive/${report##*/}"
        if [[ -e "$target" ]]; then
            echo "Warning: '$target' already exists, so '${report##*/}' stays in reports/" >&2
            continue
        fi
        mkdir -p "$reports_dir/_archive"
        mv -- "$report" "$target"
        echo "archived ${report##*/}"
    done
}

repo=""
id=""
status=""
evidence=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) [[ $# -ge 2 ]] || usage; repo=$2; shift 2 ;;
        --id) [[ $# -ge 2 ]] || usage; id=$2; shift 2 ;;
        --status) [[ $# -ge 2 ]] || usage; status=$2; shift 2 ;;
        --evidence) [[ $# -ge 2 ]] || usage; evidence=$2; shift 2 ;;
        *) echo "Error: unknown argument '$1'" >&2; usage ;;
    esac
done
[[ -n "$repo" && -n "$id" && -n "$status" ]] || usage
[[ -d "$repo" ]] || { echo "Error: --repo '$repo' is not a directory" >&2; exit 2; }
[[ "$id" =~ ^[1-9][0-9]*$ ]] || { echo "Error: --id '$id' is not a positive integer" >&2; exit 2; }
[[ "$status" == resolved || "$status" == dropped ]] || { echo "Error: --status '$status' is neither resolved nor dropped" >&2; exit 2; }
[[ -n "$evidence" && "$evidence" != *$'\n'* ]] || { echo "Error: --evidence is not one non-empty line" >&2; exit 2; }

doc_dir="$repo/.agent/doc"
[[ -d "$doc_dir" ]] || { echo "Error: '$doc_dir' not found" >&2; exit 1; }
log_path="$doc_dir/agenda-log.md"
lock_dir="$doc_dir/agenda-id.lock"

take_lock "$lock_dir"
trap 'give_lock "$lock_dir"' EXIT
# Staged under doc/ so that committing each file is a rename on one filesystem
tmp_dir=$(mktemp -d "$doc_dir/.resolve.XXXXXX")
trap 'give_lock "$lock_dir"; rm -rf -- "$tmp_dir"' EXIT

# [.] turns a fixed name into a glob, so nullglob drops it when the file is missing
agenda_files=("$doc_dir"/agenda[.]md "$doc_dir"/agenda/*.md)
index_file="$doc_dir/agenda/index.md"
match_files=()
match_line_nos=()
for file in "${agenda_files[@]}"; do
    for line_no in $(find_item_line_nos "$file" "$id"); do
        match_files+=("$file")
        match_line_nos+=("$line_no")
    done
done
if ((${#match_files[@]} == 0)); then
    echo "Error: #$id opens no item in '$doc_dir'" >&2
    exit 1
fi
mirror_line_no=""
if ((${#match_files[@]} == 1)); then
    item_file=${match_files[0]}
    item_line_no=${match_line_nos[0]}
elif ((${#match_files[@]} == 2)) && mirror_idx=$(find_index_mirror); then
    item_idx=$((1 - mirror_idx))
    item_file=${match_files[item_idx]}
    item_line_no=${match_line_nos[item_idx]}
    mirror_line_no=${match_line_nos[mirror_idx]}
else
    locations=""
    for i in "${!match_files[@]}"; do
        locations+=" ${match_files[i]#"$doc_dir/"}:${match_line_nos[i]}"
    done
    echo "Error: #$id opens more than one item:$locations" >&2
    exit 1
fi

today=$(date +%F)
item_line=$(sed -n "${item_line_no}p" "$item_file")
headline=$(calc_headline "$item_line" "$id")
heading=$(fetch_heading "$item_file" "$item_line_no")

actions="$tmp_dir/actions"
: > "$actions"
declare -A staged=()
rewrite_staged "$item_file" remove_item "$item_line_no" "$id"
if [[ -n "$mirror_line_no" ]]; then
    rewrite_staged "$index_file" remove_item "$mirror_line_no" "$id" "$(find_top_item "${staged[$item_file]}")"
fi
if [[ -n "$heading" ]]; then
    rewrite_staged "$item_file" date_heading "$heading" "$today"
    # A split-out section keeps its heading in the index too
    if is_section_file "$item_file" && [[ -f "$index_file" ]]; then
        rewrite_staged "$index_file" date_heading "$heading" "$today"
    fi
fi
for file in "${agenda_files[@]}"; do
    rewrite_staged "$file" clear_blocker "$id"
done

log_line="- $today #$id $status: $headline. $evidence"
# The log names a report by file name alone, since the report moves to _archive/
log_line=$(sed -E 's#`[^` ]*reports/(_archive/)?([^`/ ]+\.md)`#`\2`#g' <<< "$log_line")
staged_log="$tmp_dir/log"
if [[ -s "$log_path" ]]; then
    cp -- "$log_path" "$staged_log"
    [[ -z "$(tail -c 1 "$staged_log")" ]] || echo >> "$staged_log"
fi
printf '%s\n' "$log_line" >> "$staged_log"
echo "logged #$id $status in agenda-log.md" >> "$actions"

for file in "${!staged[@]}"; do
    cmp -s -- "${staged[$file]}" "$file" || mv -f -- "${staged[$file]}" "$file"
done
mv -f -- "$staged_log" "$log_path"
cat -- "$actions"

archive_closed_reports "$repo/.agent/reports" "$log_path"
