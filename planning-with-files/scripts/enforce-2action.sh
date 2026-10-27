#!/bin/bash
# planning-with-files: PreToolUse hook — mechanical 2-Action Rule enforcement.
#
# A stateful counter that blocks the model from burning through reads/writes
# without persisting findings to disk first. This breaks the
# analyze/compaction loop: the analysis is written to findings.md before it
# can be compacted away, so a later compaction no longer triggers re-analysis.
#
# State: .planning/<active-plan>/.hook_state with read_count / write_count
# (per-plan, so it resets when the active plan changes).
#
# Thresholds: N_READ (default 4) and N_WRITE (default 2), overridable via env.
#
# Per-PreToolUse logic:
#   1. Write to a planning file (task_plan/findings/progress) via any tool
#      → allow, reset both counters to 0.
#   2. Read of a planning file via any tool → allow, no count, no reset.
#   3. read_count >= N_READ or write_count >= N_WRITE → exit 2 with a reason.
#   4. Otherwise → allow, increment the appropriate counter:
#        read_count  ← Read on a non-planning file, or read-like Bash
#                      (grep/rg/find/cat/ls/head/tail/git log/git diff) on a
#                      non-planning file. A leading "cd <path> &&"/";" prefix
#                      is stripped before the read-like check.
#        write_count ← Edit/Write on a non-planning file.
#        other Bash (build/test, or on a planning file) → no increment.
#
# Edge cases:
#   - No active plan → no-op (exit 0).
#   - Corrupt state file → treated as zeroed (fail-open, never block).
#   - Bash read-like detection is a small allowlist; unknown bash neither
#     counts nor blocks.
#
# Exit codes: 0 = allow, 2 = block (reason on stderr).

set -u

N_READ="${N_READ:-4}"
N_WRITE="${N_WRITE:-2}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
RESOLVER="${SCRIPT_DIR}/resolve-plan-dir.sh"
PLAN_DIR=""
[ -f "${RESOLVER}" ] && PLAN_DIR="$(sh "${RESOLVER}" 2>/dev/null)"
# Legacy fallback: root task_plan.md (matches inject-plan.sh resolution order).
if [ -z "${PLAN_DIR}" ] && [ -f task_plan.md ]; then
    PLAN_DIR="."
fi
# No active plan → no-op.
[ -n "${PLAN_DIR}" ] && [ -f "${PLAN_DIR}/task_plan.md" ] || exit 0

STATE_FILE="${PLAN_DIR}/.hook_state"

# --- Read state (fail-open on corruption) ---
READ_COUNT=0
WRITE_COUNT=0
if [ -f "$STATE_FILE" ]; then
    RC=$(grep -E '^read_count=' "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')
    WC=$(grep -E '^write_count=' "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')
    case "$RC" in '' | *[!0-9]*) READ_COUNT=0 ;; *) READ_COUNT="$RC" ;; esac
    case "$WC" in '' | *[!0-9]*) WRITE_COUNT=0 ;; *) WRITE_COUNT="$WC" ;; esac
fi

save_state() {
    printf 'read_count=%s\nwrite_count=%s\n' "$READ_COUNT" "$WRITE_COUNT" > "$STATE_FILE" 2>/dev/null
}

# --- Classify the tool action ---
TOOL="${TOOL_NAME:-}"
INPUT="${TOOL_INPUT:-}"

get_path() {
    printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null || echo ""
}
get_command() {
    printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo ""
}

is_planning_file() {
    case "$(basename "$1")" in
        task_plan.md | findings.md | progress.md) return 0 ;;
        *) return 1 ;;
    esac
}

# A command that writes to a planning file: references a planning filename AND
# carries a write indicator (redirection, tee, sed -i, cp, mv).
cmd_writes_planning() {
    printf '%s' "$1" | grep -Eq '(task_plan|findings|progress)\.md' \
        && printf '%s' "$1" | grep -Eq '(>>?|(^|[[:space:]])tee[[:space:]]|sed[[:space:]]+-i|(^|[[:space:]])cp[[:space:]]|(^|[[:space:]])mv[[:space:]])'
}
# A read-like command (small allowlist). A leading "cd <path> &&"/";" prefix
# is stripped first so "cd /x && grep …" classifies the same as "grep …".
strip_cd_prefix() {
    printf '%s' "$1" | sed -E 's/^[[:space:]]*cd[[:space:]]+[^;&|]*(&&|;)[[:space:]]*//'
}

# A read-like command (small allowlist).
cmd_read_like() {
    _cmd="$(strip_cd_prefix "$1")"
    printf '%s' "$_cmd" | grep -Eq '^[[:space:]]*(grep|rg|find|cat|ls|head|tail|less|more)([[:space:]]|$)' \
        || printf '%s' "$_cmd" | grep -Eq '^[[:space:]]*git[[:space:]]+(log|diff)([[:space:]]|$)'
}
cmd_refs_planning() {
    printf '%s' "$1" | grep -Eq '(task_plan|findings|progress)\.md'
}

ACTION="other"
case "$TOOL" in
    read | Read)
        P="$(get_path)"
        if [ -n "$P" ] && is_planning_file "$P"; then
            ACTION="read_planning"
        else
            ACTION="read"
        fi
        ;;
    write | Write | edit | Edit)
        P="$(get_path)"
        if [ -n "$P" ] && is_planning_file "$P"; then
            ACTION="write_planning"
        else
            ACTION="write"
        fi
        ;;
    bash | Bash)
        CMD="$(get_command)"
        if cmd_writes_planning "$CMD"; then
            ACTION="write_planning"
        elif cmd_read_like "$CMD"; then
            if cmd_refs_planning "$CMD"; then
                ACTION="read_planning"
            else
                ACTION="read"
            fi
        else
            ACTION="other"
        fi
        ;;
    *)
        ACTION="other"
        ;;
esac

# --- 1. Write to a planning file → allow, reset both counters ---
if [ "$ACTION" = "write_planning" ]; then
    READ_COUNT=0
    WRITE_COUNT=0
    save_state
    exit 0
fi

# --- 2. Read of a planning file → allow, no count, no reset ---
if [ "$ACTION" = "read_planning" ]; then
    exit 0
fi

# --- 3. Threshold check → block with a concrete, actionable reason ---
if [ "$READ_COUNT" -ge "$N_READ" ] || [ "$WRITE_COUNT" -ge "$N_WRITE" ]; then
    echo "2-Action Rule: persist your findings to findings.md and update task_plan.md/progress.md before continuing. (read_count=${READ_COUNT}/${N_READ}, write_count=${WRITE_COUNT}/${N_WRITE})" >&2
    exit 2
fi

# --- 4. Otherwise → allow, increment the appropriate counter ---
case "$ACTION" in
    read) READ_COUNT=$((READ_COUNT + 1)) ;;
    write) WRITE_COUNT=$((WRITE_COUNT + 1)) ;;
    *) : ;;
esac
save_state
exit 0
