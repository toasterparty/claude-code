#!/usr/bin/env bash
# Asserts claude-code/practices/agenda/next-id.sh and resolve.sh against throwaway agendas.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )
NEXT_ID="$TOP_DIR/claude-code/practices/agenda/next-id.sh"
RESOLVE="$TOP_DIR/claude-code/practices/agenda/resolve.sh"
TODAY=$(date +%F)

total=0
failed=0

check() {
    local expected="$1" actual="$2" label="$3"
    total=$((total + 1))
    if [[ $actual != "$expected" ]]; then
        failed=$((failed + 1))
        printf 'FAIL : %s\n--- expected\n%s\n--- actual\n%s\n' "$label" "$expected" "$actual"
    fi
}

check_exit() {
    local expected="$1" label="$2" script="$3" actual=0
    shift 3
    bash "$script" "$@" >/dev/null 2>&1 || actual=$?
    check "$expected" "$actual" "$label"
}

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

new_repo() {
    local repo
    repo=$(mktemp -d "$FIXTURE_DIR/repo.XXXXXX")
    mkdir -p "$repo/.agent/doc" "$repo/.agent/reports"
    echo "$repo"
}

line_of() {
    grep -F -- "$2" "$1" || true
}

snapshot() {
    (cd "$1" && find . -type f | LC_ALL=C sort | while read -r f; do printf '%s\n' "$f"; cat "$f"; done)
}

# next-id.sh

repo=$(new_repo)
check '1' "$(bash "$NEXT_ID" --repo "$repo")" 'the first ID in an empty repo is 1'
check $'2\n3\n4' "$(bash "$NEXT_ID" --repo "$repo" --count 3)" '--count prints that many IDs in order'
check '4' "$(<"$repo/.agent/doc/agenda-id")" 'the counter records the last ID issued'

repo=$(new_repo)
printf '# Agenda\n\n## General - 2026-01-01\n- #5 Port the draw path\n' > "$repo/.agent/doc/agenda.md"
printf '40\n' > "$repo/.agent/doc/agenda-id"
check '41' "$(bash "$NEXT_ID" --repo "$repo")" 'a counter ahead of the agenda wins'

repo=$(new_repo)
printf '# Agenda\n\n## General - 2026-01-01\n- #5 Port the draw path\n' > "$repo/.agent/doc/agenda.md"
check '6' "$(bash "$NEXT_ID" --repo "$repo")" 'the highest item ID wins over a missing counter'

repo=$(new_repo)
printf '# Agenda\n\n## General - 2026-01-01\n- #5 Port the draw path\n' > "$repo/.agent/doc/agenda.md"
printf -- '- 2026-01-01 #30 resolved: Old work. Landed in a1b2c3d\n' > "$repo/.agent/doc/agenda-log.md"
check '31' "$(bash "$NEXT_ID" --repo "$repo")" 'an ID found only in the log is still in use'

repo=$(new_repo)
cat > "$repo/.agent/doc/agenda.md" <<'EOF'
# Agenda

## General - 2026-01-01
- #5 Port the draw path after PR #4521 lands
    - randomprime cites #188 and PR #194 here
EOF
printf -- '- 2026-01-01 #3 resolved: Fix #900 upstream. Merged as PR #901\n' > "$repo/.agent/doc/agenda-log.md"
check '6' "$(bash "$NEXT_ID" --repo "$repo")" 'a #N outside an item ID, a blocked by tag, or a log ID is ignored'

repo=$(new_repo)
printf '# Agenda\n\n## General - 2026-01-01\n- #5 Port the draw path `blocked by #9, #11`\n' > "$repo/.agent/doc/agenda.md"
check '12' "$(bash "$NEXT_ID" --repo "$repo")" 'an ID named in a blocked by tag is in use'

repo=$(new_repo)
mkdir -p "$repo/.agent/doc/agenda"
printf '# Agenda\n\n## Hooks - 2026-01-01\n- #2 Top item\n' > "$repo/.agent/doc/agenda/index.md"
printf '## Hooks - 2026-01-01\n- #2 Top item\n    - #20 Second item\n' > "$repo/.agent/doc/agenda/hooks.md"
check '21' "$(bash "$NEXT_ID" --repo "$repo")" 'an item ID in a split-out section file is in use'

repo=$(new_repo)
mkdir "$repo/.agent/doc/agenda-id.lock"
touch -d "@$(( $(date +%s) - 120 ))" "$repo/.agent/doc/agenda-id.lock"
check '1' "$(bash "$NEXT_ID" --repo "$repo" 2>&1)" 'a lock older than a minute is broken'
check 'gone' "$([[ -e "$repo/.agent/doc/agenda-id.lock" ]] && echo held || echo gone)" 'the lock is given back on exit'

repo=$(new_repo)
mkdir "$repo/.agent/doc/agenda-id.lock"
check_exit 1 'a fresh lock is honored' "$NEXT_ID" --repo "$repo"
check 'missing' "$([[ -e "$repo/.agent/doc/agenda-id" ]] && echo written || echo missing)" 'a run blocked by a lock writes no counter'

check_exit 2 'a zero --count is rejected' "$NEXT_ID" --repo "$repo" --count 0
check_exit 2 'an unknown argument is rejected' "$NEXT_ID" --repo "$repo" --bogus
check_exit 2 'a --repo that is not a directory is rejected' "$NEXT_ID" --repo "$FIXTURE_DIR/missing"
check 'missing' "$([[ -e "$FIXTURE_DIR/missing" ]] && echo created || echo missing)" 'a rejected --repo is not created'

repo=$(mktemp -d "$FIXTURE_DIR/bare.XXXXXX")
check '1' "$(bash "$NEXT_ID" --repo "$repo")" 'a repo without .agent/ gets its first ID'
check '*' "$(<"$repo/.agent/.gitignore")" 'a missing .agent/ is created ignoring itself'

# resolve.sh

new_resolve_repo() {
    local repo
    repo=$(new_repo)
    cat > "$repo/.agent/doc/agenda.md" <<'EOF'
# Agenda

## Config review - 2026-01-01
- #13 Script agenda removal (`config-review.md`) `open @67abf92` `Sonnet`
    - first context line
    - second context line
- #14 Consolidate the rules `blocked by #13`
    - waits on the script
- #15 Run the check `blocked by #12, #13` `User Task`

## Hooks - 2026-01-02
- #17 Narrow the gate `blocked by #13, #16`
- #18 Unrelated work `blocked by #130`
EOF
    printf -- '- 2026-01-01 #12 resolved: Earlier work. Landed in a1b2c3d\n' > "$repo/.agent/doc/agenda-log.md"
    printf -- '---\nskill: refine\nopened: [12, 13]\nclosed: []\n---\n' > "$repo/.agent/reports/20260101a-refine.md"
    printf -- '---\nskill: next\nopened: [13, 14]\nclosed: []\n---\n' > "$repo/.agent/reports/20260101b-next.md"
    printf -- '---\nskill: consult\nopened: []\nclosed: [13]\n---\n' > "$repo/.agent/reports/20260101c-consult.md"
    echo "$repo"
}

repo=$(new_resolve_repo)
agenda="$repo/.agent/doc/agenda.md"
output=$(bash "$RESOLVE" --repo "$repo" --id 13 --status resolved --evidence 'Landed in b2c3d4e')
check '' "$(line_of "$agenda" '#13 Script')$(line_of "$agenda" 'context line')" 'step 2: the item and its sub-bullets are removed'
check '    - waits on the script' "$(line_of "$agenda" 'waits on')" 'step 2: the next item keeps its own sub-bullets'
check "- $TODAY #13 resolved: Script agenda removal (\`config-review.md\`). Landed in b2c3d4e" \
    "$(tail -n 1 "$repo/.agent/doc/agenda-log.md")" 'step 3: the log gains the headline without its tags, and the evidence'
check '- 2026-01-01 #12 resolved: Earlier work. Landed in a1b2c3d' \
    "$(head -n 1 "$repo/.agent/doc/agenda-log.md")" 'step 3: earlier log lines are kept'
check '- #14 Consolidate the rules' "$(line_of "$agenda" '#14 ')" 'step 4: a tag naming only the ID is removed'
check '- #15 Run the check `blocked by #12` `User Task`' "$(line_of "$agenda" '#15 ')" 'step 4: the ID is cut from the end of a list'
check '- #17 Narrow the gate `blocked by #16`' "$(line_of "$agenda" '#17 ')" 'step 4: the ID is cut from the front of a list in another section'
check '- #18 Unrelated work `blocked by #130`' "$(line_of "$agenda" '#18 ')" 'step 4: a longer ID sharing its digits is kept'
check "## Config review - $TODAY" "$(line_of "$agenda" '## Config')" "step 5: the item's section is dated today"
check '## Hooks - 2026-01-02' "$(line_of "$agenda" '## Hooks')" 'step 5: a section that only lost a blocker keeps its date'
check 'archived' "$([[ -f "$repo/.agent/reports/_archive/20260101a-refine.md" ]] && echo archived || echo kept)" \
    'step 6: a report whose opened IDs are all logged is archived'
check 'kept' "$([[ -f "$repo/.agent/reports/20260101b-next.md" ]] && echo kept || echo archived)" \
    'step 6: a report with an opened ID still open stays'
check 'kept' "$([[ -f "$repo/.agent/reports/20260101c-consult.md" ]] && echo kept || echo archived)" \
    'step 6: a report that opened nothing stays'
check "removed #13 and 2 sub-bullet lines from agenda.md
dated \"## Config review\" $TODAY in agenda.md
cleared #13 from the blocked by tag of #14 in agenda.md
cleared #13 from the blocked by tag of #15 in agenda.md
cleared #13 from the blocked by tag of #17 in agenda.md
logged #13 resolved in agenda-log.md
archived 20260101a-refine.md" "$output" 'step 7: one line per action taken'
check 'gone' "$([[ -e "$repo/.agent/doc/agenda-id.lock" ]] && echo held || echo gone)" 'the lock is given back on exit'
check '' "$(cd "$repo/.agent/doc" && find . -name '.resolve.*')" 'the staging directory is removed on exit'

repo=$(new_resolve_repo)
mkdir "$repo/.agent/doc/agenda-id.lock"
before=$(snapshot "$repo")
check_exit 1 'the fresh lock of a next-id.sh run is honored' "$RESOLVE" --repo "$repo" --id 13 --status resolved --evidence 'x'
check "$before" "$(snapshot "$repo")" 'a run blocked by a lock changes nothing'

repo=$(new_resolve_repo)
before=$(snapshot "$repo")
check_exit 1 'step 1: an ID that opens no item is an error' "$RESOLVE" --repo "$repo" --id 99 --status resolved --evidence 'x'
check_exit 1 'step 1: an ID only named in a blocked by tag is an error' "$RESOLVE" --repo "$repo" --id 16 --status resolved --evidence 'x'
check "$before" "$(snapshot "$repo")" 'step 1: an unmatched ID changes nothing'

repo=$(new_resolve_repo)
mkdir -p "$repo/.agent/doc/agenda"
printf '## Extra - 2026-01-01\n- #13 A copy with the same ID\n' > "$repo/.agent/doc/agenda/extra.md"
before=$(snapshot "$repo")
check_exit 1 'step 1: an ID opening items in two files is an error' "$RESOLVE" --repo "$repo" --id 13 --status resolved --evidence 'x'
check "$before" "$(snapshot "$repo")" 'step 1: an ID opening items in two files changes nothing'

repo=$(new_resolve_repo)
printf -- '- #13 A copy with the same ID\n' >> "$repo/.agent/doc/agenda.md"
before=$(snapshot "$repo")
check_exit 1 'step 1: an ID opening two items in one file is an error' "$RESOLVE" --repo "$repo" --id 13 --status resolved --evidence 'x'
check "$before" "$(snapshot "$repo")" 'step 1: an ID opening two items in one file changes nothing'

new_split_repo() {
    local repo
    repo=$(new_repo)
    mkdir -p "$repo/.agent/doc/agenda"
    cat > "$repo/.agent/doc/agenda/index.md" <<'EOF'
# Agenda

## General - 2026-01-01
- #10 Loose work

## Hooks - 2026-01-02
- #20 Top item
- More in `hooks.md`
EOF
    cat > "$repo/.agent/doc/agenda/hooks.md" <<'EOF'
## Hooks - 2026-01-02
- #20 Top item
    - context for the top item
- #21 Second item
- #22 Third item `blocked by #21`
EOF
    echo "$repo"
}

repo=$(new_split_repo)
index="$repo/.agent/doc/agenda/index.md"
hooks="$repo/.agent/doc/agenda/hooks.md"
bash "$RESOLVE" --repo "$repo" --id 21 --status dropped --evidence 'No longer wanted' >/dev/null
check "## Hooks - $TODAY" "$(line_of "$hooks" '## Hooks')" 'step 5: a split-out section is dated in its own file'
check "## Hooks - $TODAY" "$(line_of "$index" '## Hooks')" 'step 5: a split-out section is dated in the index too'
check '## General - 2026-01-01' "$(line_of "$index" '## General')" 'step 5: other sections of the index keep their dates'
check '- #22 Third item' "$(line_of "$hooks" '#22 ')" 'step 4: a split-out section file is cleared too'
check "- $TODAY #21 dropped: Second item. No longer wanted" "$(<"$repo/.agent/doc/agenda-log.md")" \
    'step 3: a missing log is created with its first line, and dropped is logged as dropped'

repo=$(new_split_repo)
index="$repo/.agent/doc/agenda/index.md"
hooks="$repo/.agent/doc/agenda/hooks.md"
output=$(bash "$RESOLVE" --repo "$repo" --id 20 --status resolved --evidence 'Landed')
check "## Hooks - $TODAY
- #21 Second item
- #22 Third item \`blocked by #21\`" "$(<"$hooks")" "a split section's top item leaves its section file"
check "# Agenda

## General - 2026-01-01
- #10 Loose work

## Hooks - $TODAY
- #21 Second item
- More in \`hooks.md\`" "$(<"$index")" "a split section's top item in the index gives way to the new top item"
check "- $TODAY #20 resolved: Top item. Landed" "$(<"$repo/.agent/doc/agenda-log.md")" \
    "a split section's top item is logged once"
check "removed #20 and 1 sub-bullet lines from agenda/hooks.md
replaced #20 in agenda/index.md with the new top item #21
dated \"## Hooks\" $TODAY in agenda/hooks.md
dated \"## Hooks\" $TODAY in agenda/index.md
logged #20 resolved in agenda-log.md" "$output" "resolving a split section's top item reports the index replacement"

repo=$(new_split_repo)
index="$repo/.agent/doc/agenda/index.md"
hooks="$repo/.agent/doc/agenda/hooks.md"
printf '## Hooks - 2026-01-02\n- #20 Top item\n    - context for the top item\n' > "$hooks"
bash "$RESOLVE" --repo "$repo" --id 20 --status resolved --evidence 'Landed' >/dev/null
check "## Hooks - $TODAY" "$(<"$hooks")" "a split section's last item leaves its section file"
check "# Agenda

## General - 2026-01-01
- #10 Loose work

## Hooks - $TODAY
- More in \`hooks.md\`" "$(<"$index")" "a split section's last item leaves the index with no copy"

repo=$(new_split_repo)
printf '# Agenda\n\n## General - 2026-01-01\n- #20 Top item\n' > "$repo/.agent/doc/agenda/index.md"
before=$(snapshot "$repo")
check_exit 1 'step 1: an index copy under another section is an error' "$RESOLVE" --repo "$repo" --id 20 --status resolved --evidence 'x'
check "$before" "$(snapshot "$repo")" 'step 1: an index copy under another section changes nothing'

# A Windows path separator here, and a literal path on Linux
repo="$FIXTURE_DIR"'/back\slash'
mkdir -p "$repo/.agent/doc/agenda" "$repo/.agent/reports"
cat > "$repo/.agent/doc/agenda/index.md" <<'EOF'
# Agenda

## Paths like C:\temp - 2026-01-02
- #20 Top item
- More in `paths.md`
EOF
cat > "$repo/.agent/doc/agenda/paths.md" <<'EOF'
## Paths like C:\temp - 2026-01-02
- #20 Top item
- #21 Fix the \n escape
EOF
check_exit 0 'a backslash in the repo path is kept' "$RESOLVE" --repo "$repo" --id 20 --status resolved --evidence 'Landed'
check "# Agenda

## Paths like C:\\temp - $TODAY
- #21 Fix the \\n escape
- More in \`paths.md\`" "$(<"$repo/.agent/doc/agenda/index.md")" 'a backslash in a heading or an item is kept'

repo=$(new_repo)
printf '# Agenda\n\n## General - 2026-01-01\n- #4 Review the run (`../reports/_archive/20260101a-next.md`)\n' > "$repo/.agent/doc/agenda.md"
printf -- '- 2026-01-01 #3 resolved: Earlier. Landed' > "$repo/.agent/doc/agenda-log.md"
bash "$RESOLVE" --repo "$repo" --id 4 --status resolved --evidence 'Reviewed in `reports/20260102a-next.md`' >/dev/null
check "- 2026-01-01 #3 resolved: Earlier. Landed
- $TODAY #4 resolved: Review the run (\`20260101a-next.md\`). Reviewed in \`20260102a-next.md\`" \
    "$(<"$repo/.agent/doc/agenda-log.md")" 'step 3: a report is logged by file name alone, after a log missing its final newline'

repo=$(new_resolve_repo)
check_exit 2 'a status other than resolved or dropped is rejected' "$RESOLVE" --repo "$repo" --id 13 --status done --evidence 'x'
check_exit 2 'an empty evidence is rejected' "$RESOLVE" --repo "$repo" --id 13 --status resolved --evidence ''
check_exit 2 'a two-line evidence is rejected' "$RESOLVE" --repo "$repo" --id 13 --status resolved --evidence $'One\nTwo'
check_exit 2 'a non-numeric ID is rejected' "$RESOLVE" --repo "$repo" --id '#13' --status resolved --evidence 'x'
check_exit 2 'a --repo that is not a directory is rejected' "$RESOLVE" --repo "$FIXTURE_DIR/missing" --id 13 --status resolved --evidence 'x'

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
