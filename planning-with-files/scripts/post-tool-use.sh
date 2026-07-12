#!/bin/bash
# planning-with-files: PostToolUse hook — remind to update progress.md.
#
# Checks if an active plan exists (using resolve-plan-dir.sh) and prints a
# reminder to update progress.md with what was just done.
#
# Guard: If the tool that just ran was editing progress.md or task_plan.md,
# skip the reminder to avoid an endless loop (edit progress.md -> reminder ->
# edit progress.md again).
#
# Always exits 0. Never blocks the tool call.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
RESOLVER="${SCRIPT_DIR}/resolve-plan-dir.sh"
PLAN_DIR=""

if [ -f "${RESOLVER}" ]; then
    PLAN_DIR="$(sh "${RESOLVER}" 2>/dev/null)"
fi

if [ -n "${PLAN_DIR}" ] && [ -f "${PLAN_DIR}/task_plan.md" ]; then
    # Only remind for Edit/Write tools (not Read, Bash, etc.)
    # Guard: skip reminder if the tool just edited progress.md or task_plan.md
    if [ -n "${TOOL_NAME:-}" ]; then
        case "${TOOL_NAME}" in
            edit|write)
                # Check if the file being edited is progress.md or task_plan.md
                FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null || echo "")
                if [ -n "$FILE_PATH" ]; then
                    BASENAME=$(basename "$FILE_PATH")
                    if [ "$BASENAME" = "progress.md" ] || [ "$BASENAME" = "task_plan.md" ]; then
                        exit 0
                    fi
                fi
                echo '[planning-with-files] Update progress.md NOW — log what you just did before moving on. Do not batch changes; update after every tool call. If a phase is complete, also update task_plan.md status.'
                ;;
        esac
    fi
fi
exit 0
