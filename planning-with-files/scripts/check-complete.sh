#!/usr/bin/env bash
# Check if all phases in task_plan.md are complete
# Always exits 0 in manual mode — uses stdout for status reporting
# With --strict: exits 1 if any phase is incomplete (used by the Stop hook)
#
# Plan-file resolution (v2.40+):
#   1. $1 (explicit path)
#   2. resolve-plan-dir.sh: $PLAN_ID env → .planning/.active_plan → newest mtime
#   3. Legacy ./task_plan.md
#
# This restores slug-mode parity: the Stop hook and any caller invoking with
# zero args now respects the active plan dir instead of silently defaulting to
# the legacy root path.

STRICT=0
PLAN_ARG=""
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        *) PLAN_ARG="$arg" ;;
    esac
done

if [ -n "$PLAN_ARG" ]; then
    PLAN_FILE="$PLAN_ARG"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
    RESOLVER="${SCRIPT_DIR}/resolve-plan-dir.sh"
    PLAN_DIR=""
    if [ -f "${RESOLVER}" ]; then
        PLAN_DIR="$(sh "${RESOLVER}" 2>/dev/null)"
    fi
    if [ -n "${PLAN_DIR}" ] && [ -f "${PLAN_DIR}/task_plan.md" ]; then
        PLAN_FILE="${PLAN_DIR}/task_plan.md"
    else
        PLAN_FILE="task_plan.md"
    fi
fi

if [ ! -f "$PLAN_FILE" ]; then
    if [ "$STRICT" -eq 0 ]; then
        echo "[planning-with-files] No task_plan.md found — no active planning session."
    fi
    exit 0
fi

# Count total phases
TOTAL=$(grep -c "### Phase" "$PLAN_FILE" || true)

# Check for **Status:** format first
COMPLETE=$(grep -cF "**Status:** complete" "$PLAN_FILE" || true)
IN_PROGRESS=$(grep -cF "**Status:** in_progress" "$PLAN_FILE" || true)
PENDING=$(grep -cF "**Status:** pending" "$PLAN_FILE" || true)

# Fallback: check for [complete] inline format if **Status:** not found
if [ "$COMPLETE" -eq 0 ] && [ "$IN_PROGRESS" -eq 0 ] && [ "$PENDING" -eq 0 ]; then
    COMPLETE=$(grep -c "\[complete\]" "$PLAN_FILE" || true)
    IN_PROGRESS=$(grep -c "\[in_progress\]" "$PLAN_FILE" || true)
    PENDING=$(grep -c "\[pending\]" "$PLAN_FILE" || true)
fi

# Default to 0 if empty
: "${TOTAL:=0}"
: "${COMPLETE:=0}"
: "${IN_PROGRESS:=0}"
: "${PENDING:=0}"

# Report status (manual mode always exits 0 — incomplete task is a normal state)
# In --strict mode the output is suppressed (the hook only reads the exit code).
if [ "$STRICT" -eq 0 ]; then
    if [ "$COMPLETE" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo "[planning-with-files] ALL PHASES COMPLETE ($COMPLETE/$TOTAL). If the user has additional work, add new phases to task_plan.md before starting."
    else
        echo "[planning-with-files] Task in progress ($COMPLETE/$TOTAL phases complete). Update progress.md before stopping."
        if [ "$IN_PROGRESS" -gt 0 ]; then
            echo "[planning-with-files] $IN_PROGRESS phase(s) still in progress."
        fi
        if [ "$PENDING" -gt 0 ]; then
            echo "[planning-with-files] $PENDING phase(s) pending."
        fi
    fi
fi

# --strict: exit 1 if any phase is incomplete (no plan → 0, nothing to check)
if [ "$STRICT" -eq 1 ]; then
    if [ "$COMPLETE" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        exit 0
    fi
    exit 1
fi
exit 0
