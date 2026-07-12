#!/bin/bash
# planning-with-files: Stop-hook dispatcher for Respondami (Tier 2: notification only).
#
# Simplified from Claude version: Respondami cannot hard-block the stop event,
# so this script always runs in advisory mode (no gate enforcement).
# It reports task completion status via stdout. The agent can use this
# information to decide whether to continue working.
#
# Always exits 0. Never blocks the stop.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."

TARGET="${SCRIPT_DIR}/check-complete.sh"
[ -f "$TARGET" ] || exit 0

sh "$TARGET"
exit 0
