# Sourced by the practice scripts for a lock shared across sessions: a directory, since mkdir is
# atomic. A lock older than LOCK_STALE_MIN was left by a killed run, as no holder keeps one that long.
LOCK_WAIT_TENTHS=50
LOCK_STALE_MIN=1

take_lock() {
    local lock_dir=$1 i
    find "$lock_dir" -maxdepth 0 -type d -mmin "+$LOCK_STALE_MIN" -exec rmdir -- {} + 2>/dev/null || true
    for ((i = 0; i < LOCK_WAIT_TENTHS; i++)); do
        mkdir -- "$lock_dir" 2>/dev/null && return
        sleep 0.1
    done
    echo "Error: lock '$lock_dir' still held after $((LOCK_WAIT_TENTHS / 10))s" >&2
    exit 1
}

give_lock() {
    rmdir -- "$1" 2>/dev/null || true
}
