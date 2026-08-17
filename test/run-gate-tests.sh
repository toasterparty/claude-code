#!/usr/bin/env bash
# Asserts permission-gate.sh against test/gate-cases.tsv. Run run-gate-tests.ps1 for the .ps1 twin.
set -euo pipefail
shopt -s nullglob
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOP_DIR=$( git -C "$SCRIPT_DIR" rev-parse --show-toplevel )

source "$TOP_DIR/claude-code/hooks/permission-gate.sh"

total=0
failed=0
while IFS=$'\t' read -r expected command_text; do
    if [[ -z $expected || $expected == \#* ]]; then
        continue
    fi

    total=$((total + 1))
    gate_decision "${command_text:-}"
    if [[ $GATE_DECISION != "$expected" ]]; then
        failed=$((failed + 1))
        printf 'FAIL expected=%s actual=%s : %s\n' "$expected" "$GATE_DECISION" "${command_text:-}"
    fi
done < "$SCRIPT_DIR/gate-cases.tsv"

printf '%s/%s passed\n' "$((total - failed))" "$total"
[[ $failed -eq 0 ]]
