#!/bin/bash
# planning-with-files: PostToolUse hook — mechanical hook log + reminder.
#
# After every model write/edit (except on the planning files themselves),
# appends a one-line mechanical entry to the `## Hook Log` section of
# progress.md, then prints a reminder to add a descriptive entry.
#
# The mechanical line is the durability floor: if a session is interrupted
# (compaction, crash), the file-level record of what changed is already on
# disk, independent of the model's cooperation.
#
# Guard: If the tool that just ran was editing progress.md or task_plan.md,
# skip both the append and the reminder to avoid an endless loop.
#
# The hook's own append is not a model tool call, so it cannot retrigger
# this hook (no recursion by construction).
#
# Always exits 0. Never blocks the tool call.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
RESOLVER="${SCRIPT_DIR}/resolve-plan-dir.sh"
PLAN_DIR=""

if [ -f "${RESOLVER}" ]; then
    PLAN_DIR="$(sh "${RESOLVER}" 2>/dev/null)"
fi

# Legacy fallback: root task_plan.md (matches inject-plan.sh resolution order)
if [ -z "${PLAN_DIR}" ] && [ -f task_plan.md ]; then
    PLAN_DIR="."
fi

if [ -n "${PLAN_DIR}" ] && [ -f "${PLAN_DIR}/task_plan.md" ]; then
    # Only act for Edit/Write tools (not Read, Bash, etc.)
    # Guard: skip if the tool just edited progress.md or task_plan.md
    if [ -n "${TOOL_NAME:-}" ]; then
        case "${TOOL_NAME}" in
            edit|write)
                # Check if the file being edited is progress.md or task_plan.md
                FILE_PATH=$(echo "${TOOL_INPUT:-}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null || echo "")
                if [ -n "$FILE_PATH" ]; then
                    BASENAME=$(basename "$FILE_PATH")
                    if [ "$BASENAME" = "progress.md" ] || [ "$BASENAME" = "task_plan.md" ]; then
                        exit 0
                    fi
                fi

                # --- Mechanical hook log ---
                PROGRESS_FILE="${PLAN_DIR}/progress.md"
                if [ -n "$FILE_PATH" ]; then
                    TS=$(date +%H:%M:%S 2>/dev/null || echo "00:00:00")
                    LINES=""
                    if [ -f "$FILE_PATH" ]; then
                        LC=$(wc -l < "$FILE_PATH" 2>/dev/null | tr -d '[:space:]')
                        [ -n "$LC" ] && LINES=" (${LC} lines)"
                    fi
                    # Path relative to CWD when possible
                    REL_PATH="$FILE_PATH"
                    case "$FILE_PATH" in
                        ./*) REL_PATH="${FILE_PATH#./}" ;;
                        "${PWD}"/*) REL_PATH="${FILE_PATH#"${PWD}"/}" ;;
                    esac
                    ENTRY="- [${TS}] ${TOOL_NAME}: ${REL_PATH}${LINES}"
                    if [ -f "$PROGRESS_FILE" ] && grep -q '^## Hook Log' "$PROGRESS_FILE" 2>/dev/null; then
                        printf '%s\n' "$ENTRY" >> "$PROGRESS_FILE" 2>/dev/null
                    else
                        printf '\n## Hook Log\n%s\n' "$ENTRY" >> "$PROGRESS_FILE" 2>/dev/null
                    fi
                fi

                echo '[planning-with-files] A mechanical entry for this change was just appended to the ## Hook Log in progress.md. Now add your descriptive entry (what and why) to the session log. If a phase is complete, also update task_plan.md status.'
                ;;
        esac
    fi
fi
exit 0
