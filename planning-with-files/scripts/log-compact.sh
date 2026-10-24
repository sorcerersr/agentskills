#!/bin/bash
# planning-with-files: PostCompact hook — record the compaction in progress.md.
#
# A pure side effect: appends one line to the `## Compactions` section of
# progress.md noting that a compaction occurred and the plan was preserved via
# the PreCompact marker. No model injection.
#
# Env: COMPACT_TRIGGER (manual/auto), COMPACT_MESSAGES_REMOVED (count).
#
# No active plan, or no progress.md → no-op. Always exits 0. Never blocks.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
RESOLVER="${SCRIPT_DIR}/resolve-plan-dir.sh"
PLAN_DIR=""
[ -f "${RESOLVER}" ] && PLAN_DIR="$(sh "${RESOLVER}" 2>/dev/null)"
# Legacy fallback: root task_plan.md (matches inject-plan.sh resolution order).
if [ -z "${PLAN_DIR}" ] && [ -f task_plan.md ]; then
    PLAN_DIR="."
fi
[ -n "${PLAN_DIR}" ] && [ -f "${PLAN_DIR}/task_plan.md" ] || exit 0

PROGRESS_FILE="${PLAN_DIR}/progress.md"
[ -f "$PROGRESS_FILE" ] || exit 0

TS=$(date +%H:%M:%S 2>/dev/null || echo "00:00:00")
TRIGGER="${COMPACT_TRIGGER:-auto}"
REMOVED="${COMPACT_MESSAGES_REMOVED:-?}"
# Per-plan compaction ordinal: count existing entries, then add this one.
N=$(grep -cE '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] compaction' "$PROGRESS_FILE" 2>/dev/null)
N=$((N + 1))
ENTRY="- [${TS}] compaction ${N} (${TRIGGER}): ${REMOVED} messages removed; plan preserved via PreCompact marker"

if grep -q '^## Compactions' "$PROGRESS_FILE" 2>/dev/null; then
    printf '%s\n' "$ENTRY" >> "$PROGRESS_FILE" 2>/dev/null
else
    printf '\n## Compactions\n%s\n' "$ENTRY" >> "$PROGRESS_FILE" 2>/dev/null
fi
exit 0
