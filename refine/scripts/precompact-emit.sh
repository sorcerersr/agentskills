#!/bin/sh
# Re-emit the file pinned by a state file, marker-wrapped, for PreCompact.
# Usage: precompact-emit.sh <state-file>
set -u
STATE="${1:-}"
[ -n "$STATE" ] && [ -f "$STATE" ] || exit 0
PATH_LINE=$(tr -d '\r\n[:space:]' < "$STATE" 2>/dev/null)
[ -n "$PATH_LINE" ] && [ -f "$PATH_LINE" ] || exit 0
echo '===BEGIN PLAN DATA==='
cat "$PATH_LINE"
echo '===END PLAN DATA==='
exit 0
