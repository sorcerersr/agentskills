#!/bin/sh
# Tests for precompact-emit.sh (identical in refine/, code-health-check/, arch-review/).
# Run from anywhere: sh test-hooks.sh
set -u

ROOT=$(cd "$(dirname "$0")" && pwd)
FAIL=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

for skill in refine code-health-check arch-review; do
    SCRIPT="$ROOT/$skill/scripts/precompact-emit.sh"
    if [ ! -x "$SCRIPT" ]; then
        fail "$skill: script missing or not executable"
        continue
    fi

    T=$(mktemp -d)
    printf 'line one\nline two\n' > "$T/artifact.md"

    # 1. valid state file -> marked output, exit 0
    printf 'artifact.md\n' > "$T/.state"
    OUT=$(cd "$T" && sh "$SCRIPT" .state)
    RC=$?
    EXPECT=$(printf '===BEGIN PLAN DATA===\nline one\nline two\n===END PLAN DATA===')
    if [ "$RC" -eq 0 ] && [ "$OUT" = "$EXPECT" ]; then
        pass "$skill: valid state file -> marked output, exit 0"
    else
        fail "$skill: valid state file (rc=$RC)"
    fi

    # 2. missing state file -> empty output, exit 0
    OUT=$(cd "$T" && sh "$SCRIPT" .nope)
    RC=$?
    if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then
        pass "$skill: missing state file -> empty output, exit 0"
    else
        fail "$skill: missing state file (rc=$RC)"
    fi

    # 3. state file pointing to a missing file -> empty output, exit 0
    printf 'gone.md\n' > "$T/.state2"
    OUT=$(cd "$T" && sh "$SCRIPT" .state2)
    RC=$?
    if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then
        pass "$skill: dangling path -> empty output, exit 0"
    else
        fail "$skill: dangling path (rc=$RC)"
    fi

    rm -rf "$T"
done

# 4. all three copies byte-identical
A=$(md5sum "$ROOT/refine/scripts/precompact-emit.sh" | cut -d' ' -f1)
B=$(md5sum "$ROOT/code-health-check/scripts/precompact-emit.sh" | cut -d' ' -f1)
C=$(md5sum "$ROOT/arch-review/scripts/precompact-emit.sh" | cut -d' ' -f1)
if [ "$A" = "$B" ] && [ "$B" = "$C" ]; then
    pass "three script copies byte-identical"
else
    fail "script copies differ ($A $B $C)"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "ALL TESTS PASSED"
else
    echo "TESTS FAILED"
fi
exit "$FAIL"
