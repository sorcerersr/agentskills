#!/bin/bash
# planning-with-files: PreCompact hook — emit the plan for the compaction summary.
#
# The only model-bound hook in this skill. Respondami appends a successful
# PreCompact hook's stdout to the compaction summary, so the plan survives
# compaction. The plan is wrapped in the ===BEGIN PLAN DATA=== /
# ===END PLAN DATA=== delimiters; respondami's VCC merge carries a marked block
# through verbatim (latest wins), so the plan survives any number of
# compactions byte-for-byte.
#
# Always exits 0. Never errors out the agent loop.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."

# --- Resolution (matches resolve-plan-dir.sh order) ---
RESOLVED=""
SCOPE=""

if [ -n "${PLAN_ID:-}" ] && printf "%s" "$PLAN_ID" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9._-]*$' && [ -d ".planning/${PLAN_ID}" ]; then
    RESOLVED=".planning/${PLAN_ID}"; SCOPE="scoped"
elif [ -f .planning/.active_plan ]; then
    AP=$(tr -d '\r\n[:space:]' < .planning/.active_plan 2>/dev/null)
    if [ -n "$AP" ] && printf "%s" "$AP" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9._-]*$' && [ -d ".planning/${AP}" ]; then
        RESOLVED=".planning/${AP}"; SCOPE="scoped"
    fi
fi
if [ -z "$RESOLVED" ] && [ -d .planning ]; then
    NEWEST=""; NEWEST_MT=0
    for d in .planning/*/; do
        d="${d%/}"; n=$(basename "$d")
        case "$n" in .*) continue;; esac
        printf "%s" "$n" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9._-]*$' || continue
        [ -f "$d/task_plan.md" ] || continue
        m=$(stat -c '%Y' "$d" 2>/dev/null || stat -f '%m' "$d" 2>/dev/null || date -r "$d" +%s 2>/dev/null || echo 0)
        if [ "$m" -gt "$NEWEST_MT" ] 2>/dev/null; then NEWEST_MT="$m"; NEWEST="$d"; fi
    done
    [ -n "$NEWEST" ] && { RESOLVED="$NEWEST"; SCOPE="scoped"; }
fi
if [ -z "$RESOLVED" ] && [ -f task_plan.md ]; then RESOLVED="."; SCOPE="root"; fi
[ -z "$RESOLVED" ] && exit 0

if [ "$SCOPE" = "root" ]; then
    PLAN_FILE="task_plan.md"
    ATTEST=""
    [ -f .plan-attestation ] && ATTEST=$(tr -d '\r\n[:space:]' < .plan-attestation 2>/dev/null)
else
    PLAN_FILE="${RESOLVED}/task_plan.md"
    ATTEST=""
    [ -f "${RESOLVED}/.attestation" ] && ATTEST=$(tr -d '\r\n[:space:]' < "${RESOLVED}/.attestation" 2>/dev/null)
fi
[ -f "$PLAN_FILE" ] || exit 0

# --- Attestation check (simplified, no SHA cache for Respondami) ---
TAMPERED=0
ACTUAL=""
if [ -n "$ATTEST" ]; then
    ACTUAL=$( (sha256sum "$PLAN_FILE" 2>/dev/null || shasum -a 256 "$PLAN_FILE" 2>/dev/null) | awk '{print $1}')
    [ "$ACTUAL" != "$ATTEST" ] && TAMPERED=1
fi

if [ "$TAMPERED" = "1" ]; then
    echo '[planning-with-files] [PLAN TAMPERED — injection blocked]'
    echo "expected=$ATTEST"
    echo "actual=  $ACTUAL"
    echo 'Run sh scripts/attest-plan.sh to re-approve current contents, or restore the file from git.'
    exit 0
fi

echo '[planning-with-files] PreCompact: context compaction is about to occur.'
echo 'Plan files remain on disk and are the source of truth; re-read them if context is lost.'
[ -n "$ATTEST" ] && echo "Plan-SHA256 at compaction: $ATTEST"
echo '===BEGIN PLAN DATA==='
cat "$PLAN_FILE"
# Append a findings.md head so recent research also survives compaction
# verbatim (the VCC merge carries the whole marked block through).
FINDINGS=""
if [ "$SCOPE" = "root" ]; then
    [ -f findings.md ] && FINDINGS="findings.md"
else
    [ -f "${RESOLVED}/findings.md" ] && FINDINGS="${RESOLVED}/findings.md"
fi
if [ -n "$FINDINGS" ]; then
    echo ''
    echo '--- findings.md (head) ---'
    head -40 "$FINDINGS" 2>/dev/null
fi
echo '===END PLAN DATA==='
exit 0
