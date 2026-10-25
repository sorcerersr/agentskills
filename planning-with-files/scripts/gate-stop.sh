#!/bin/bash
# planning-with-files: Stop hook — completion gate.
#
# Vetoes the stop while the active plan is incomplete. Runs
# check-complete.sh --strict; if the plan has incomplete phases, exits 2 with
# a concrete reason, which Respondami feeds back to the model as a new turn.
# The model must finish the current phase and update the planning files
# before it can stop.
#
# No active plan → exit 0 (never blocks a stop in a project without a plan).
#
# Exit codes: 0 = allow stop, 2 = veto stop (reason on stderr).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
TARGET="${SCRIPT_DIR}/check-complete.sh"
[ -f "$TARGET" ] || exit 0

sh "$TARGET" --strict
RC=$?

if [ "$RC" -eq 0 ]; then
    exit 0
fi

# Incomplete plan → veto the stop with a concrete, actionable reason.
# Re-run in manual mode to get the N/M, X, Y counts for the message.
STATUS=$(sh "$TARGET" 2>/dev/null)
COMPLETE=$(printf '%s\n' "$STATUS" | grep -oE '[0-9]+/[0-9]+' | head -1)
IN_PROGRESS=$(printf '%s\n' "$STATUS" | grep -oE '[0-9]+ phase\(s\) still in progress' | head -1 | grep -oE '^[0-9]+')
PENDING=$(printf '%s\n' "$STATUS" | grep -oE '[0-9]+ phase\(s\) pending' | head -1 | grep -oE '^[0-9]+')
: "${COMPLETE:=?/?}"
: "${IN_PROGRESS:=0}"
: "${PENDING:=0}"

echo "Plan incomplete: ${COMPLETE} phases complete (${IN_PROGRESS} in progress, ${PENDING} pending). Finish the current phase, update task_plan.md and progress.md, then stop." >&2
exit 2
