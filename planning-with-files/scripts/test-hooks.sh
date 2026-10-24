#!/bin/bash
# planning-with-files: hook script tests (design 2026-10-24).
#
# Self-contained: generates synthetic fixtures in a mktemp -d scratch dir,
# runs the hook scripts against them, asserts on the output. All fixtures
# are fictional (Acme CLI project) — no real project content.
#
# Usage: sh scripts/test-hooks.sh
# Exits non-zero on any failure. Prints a PASS/FAIL summary.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
INJECT="${SCRIPT_DIR}/inject-plan.sh"
POST="${SCRIPT_DIR}/post-tool-use.sh"
ENFORCE="${SCRIPT_DIR}/enforce-2action.sh"
LOGC="${SCRIPT_DIR}/log-compact.sh"
ATTEST="${SCRIPT_DIR}/attest-plan.sh"
INIT="${SCRIPT_DIR}/init-session.sh"
RESOLVER="${SCRIPT_DIR}/resolve-plan-dir.sh"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FATAL: cannot create scratch dir" >&2; exit 1; }
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
FAILED_NAMES=""

ok()   { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); FAILED_NAMES="${FAILED_NAMES}
  - $1"; printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; }

# assert_contains <name> <haystack> <needle>
assert_contains() {
    case "$2" in
        *"$3"*) ok "$1" ;;
        *) bad "$1" "missing: $3" ;;
    esac
}

# assert_not_contains <name> <haystack> <needle>
assert_not_contains() {
    case "$2" in
        *"$3"*) bad "$1" "should not contain: $3" ;;
        *) ok "$1" ;;
    esac
}

# ---------------------------------------------------------------------------
# Fixture: 7-phase synthetic plan (Acme CLI), field Phase 6, Phase 6 in_progress
# ---------------------------------------------------------------------------
write_plan7() {
    cat > task_plan.md <<'EOF'
# Task Plan: Acme CLI — Report Export

## Goal
Implement the report export feature: CSV + PDF output, streaming writer,
CLI flags, and a green test/clippy/fmt gate.

## Current Phase
Phase 6

## Phases

### Phase 1: Setup & API Verification
- [x] Add dependencies to Cargo.toml
- [x] Verify writer APIs against docs
- [x] `cargo build` compiles empty skeleton
- **Status:** complete

### Phase 2: Core Shell (config, output)
- [x] `config.rs`: output format + path settings
- [x] `output.rs`: writer trait + CSV impl
- [x] Unit tests: config round-trip
- [x] `cargo test` green (13 tests)
- **Status:** complete

### Phase 3: PDF Writer
- [x] `pdf.rs`: table layout + streaming
- [x] Unit tests: page breaks
- [x] `cargo test` green (21 tests)
- **Status:** complete

### Phase 4: CLI Flags
- [x] `cli.rs`: --format, --out, --stream
- [x] Integration tests: flag parsing
- [x] `cargo test` green (34 tests)
- **Status:** complete

### Phase 5: Error Handling
- [x] `error.rs`: thiserror enum + context
- [x] Map writer errors to exit codes
- [x] `cargo test` green (41 tests), clippy clean
- **Status:** complete

### Phase 6: Smoke Test & Verification
- [ ] `tests/smoke.rs`: end-to-end export, file checks
- [ ] Gate: `cargo test` + `cargo clippy` + `cargo fmt` all green
- [ ] M1 checklist verified item by item
- **Status:** in_progress

### Phase 7: Delivery
- [ ] Review outputs against design
- [ ] Summarize to user
- **Status:** pending

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Streaming writer | Large reports must not buffer in memory |
EOF
}

# ---------------------------------------------------------------------------
# Test 1: precompact emits full plan body + markers
# ---------------------------------------------------------------------------
cd "$WORK" || exit 1
write_plan7
OUT=$(sh "$INJECT" --context=precompact)
assert_contains   "1a precompact: note"        "$OUT" "PreCompact"
assert_contains   "1b precompact: plan body"   "$OUT" "### Phase 6: Smoke Test & Verification"
assert_contains   "1c precompact: begin marker" "$OUT" "===BEGIN PLAN DATA==="
assert_contains   "1d precompact: end marker"   "$OUT" "===END PLAN DATA==="
# Markers must be clean (no trailing space) so the VCC merge matches them.
assert_not_contains "1e precompact: no trailing space" "$OUT" "===BEGIN PLAN DATA=== "

# ---------------------------------------------------------------------------
# Test 2: precompact with attestation → sha line present
# ---------------------------------------------------------------------------
sh "$ATTEST" >/dev/null 2>&1
OUT=$(sh "$INJECT" --context=precompact)
assert_contains "2a attested precompact: sha line" "$OUT" "Plan-SHA256 at compaction"
assert_contains "2b attested precompact: body"     "$OUT" "===BEGIN PLAN DATA==="

# ---------------------------------------------------------------------------
# Test 3: tampered attested plan → injection blocked
# ---------------------------------------------------------------------------
printf 'tampered line\n' >> task_plan.md
OUT=$(sh "$INJECT" --context=precompact)
assert_contains   "3a tampered precompact: blocked" "$OUT" "[PLAN TAMPERED"
assert_not_contains "3b tampered precompact: no body" "$OUT" "===BEGIN PLAN DATA==="
sh "$ATTEST" --clear >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Test 4: no plan → total silence
# ---------------------------------------------------------------------------
mkdir -p t4 && cd t4 || exit 1
OUT=$(sh "$INJECT" --context=precompact)
[ -z "$OUT" ] && ok "4a no plan: inject silent" || bad "4a no plan: inject silent" "output: $OUT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 5: post-tool-use appends a mechanical line (no reminder)
# ---------------------------------------------------------------------------
mkdir -p t5 && cd t5 || exit 1
write_plan7
printf '# Progress Log\n\n## Session: 2026-10-24\n' > progress.md
mkdir -p src
printf 'fn main() {}\n' > src/main.rs
OUT=$(TOOL_NAME=write TOOL_INPUT='{"path":"src/main.rs"}' sh "$POST")
[ -z "$OUT" ] && ok "5a post: no reminder output" || bad "5a post: no reminder output" "output: $OUT"
LINE=$(grep -E '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] write: src/main.rs \(1 lines\)$' progress.md)
[ -n "$LINE" ] && ok "5b hook log line format" || bad "5b hook log line format" "no matching line in:"
for l in $(tail -3 progress.md); do printf '      %s\n' "$l"; done
OUT=$(TOOL_NAME=write TOOL_INPUT='{"path":"src/util.rs"}' sh "$POST")
COUNT=$(grep -cE '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] (write|edit):' progress.md)
[ "$COUNT" = "2" ] && ok "5c second line appended" || bad "5c second line appended" "expected 2 hook log lines, got $COUNT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 6: loop guard — edits to planning files are silent
# ---------------------------------------------------------------------------
cd t5 || exit 1
BEFORE=$(wc -l < progress.md)
OUT=$(TOOL_NAME=edit TOOL_INPUT='{"path":"progress.md"}' sh "$POST")
[ -z "$OUT" ] && ok "6a guard progress.md silent" || bad "6a guard progress.md silent" "output: $OUT"
OUT=$(TOOL_NAME=edit TOOL_INPUT='{"path":"task_plan.md"}' sh "$POST")
[ -z "$OUT" ] && ok "6b guard task_plan.md silent" || bad "6b guard task_plan.md silent" "output: $OUT"
AFTER=$(wc -l < progress.md)
[ "$BEFORE" = "$AFTER" ] && ok "6c no append for planning files" || bad "6c no append for planning files" "progress.md grew"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 7: no plan → post silent
# ---------------------------------------------------------------------------
mkdir -p t7 && cd t7 || exit 1
OUT=$(TOOL_NAME=write TOOL_INPUT='{"path":"a.rs"}' sh "$POST")
[ -z "$OUT" ] && ok "7a no plan: post silent" || bad "7a no plan: post silent" "output: $OUT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 8: progress.md without Hook Log section → section created
# ---------------------------------------------------------------------------
mkdir -p t8 && cd t8 || exit 1
write_plan7
printf '# Progress Log\n\nno section yet\n' > progress.md
printf 'x\n' > a.rs
TOOL_NAME=write TOOL_INPUT='{"path":"a.rs"}' sh "$POST" >/dev/null
grep -q '^## Hook Log' progress.md && ok "8a section created" || bad "8a section created" "no ## Hook Log heading"
grep -qE '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] write: a.rs \(1 lines\)$' progress.md && ok "8b line under section" || bad "8b line under section" "no hook log line"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 9: .planning/-only flow (init-session.sh owns creation)
# ---------------------------------------------------------------------------
mkdir -p t9 && cd t9 || exit 1
OUT=$(sh "$INIT" "Acme CLI")
PLAN_ID_LINE=$(printf '%s\n' "$OUT" | grep '^PLAN_ID=' | cut -d= -f2)
[ -n "$PLAN_ID_LINE" ] && ok "9a init: PLAN_ID printed" || bad "9a init: PLAN_ID printed" "no PLAN_ID in output"
PLAN_DIR_T9=".planning/${PLAN_ID_LINE}"
[ -f "${PLAN_DIR_T9}/task_plan.md" ] && [ -f "${PLAN_DIR_T9}/findings.md" ] && [ -f "${PLAN_DIR_T9}/progress.md" ] \
    && ok "9b init: 3 files in plan dir" || bad "9b init: 3 files in plan dir" "missing files in ${PLAN_DIR_T9}"
[ ! -f task_plan.md ] && [ ! -f findings.md ] && [ ! -f progress.md ] \
    && ok "9c init: root stays clean" || bad "9c init: root stays clean" "planning file leaked to root"
[ -f .planning/.active_plan ] && [ "$(cat .planning/.active_plan)" = "$PLAN_ID_LINE" ] \
    && ok "9d init: .active_plan pinned" || bad "9d init: .active_plan pinned" "active plan mismatch"
RESOLVED=$(sh "$RESOLVER")
[ "$RESOLVED" = "${PWD}/${PLAN_DIR_T9}" ] && ok "9e resolver: prints plan dir" || bad "9e resolver: prints plan dir" "got: $RESOLVED"
printf 'fn main() {}\n' > src_file.rs
OUT=$(TOOL_NAME=write TOOL_INPUT='{"path":"src_file.rs"}' sh "$POST")
[ -z "$OUT" ] && ok "9f post: no reminder" || bad "9f post: no reminder" "output: $OUT"
grep -qE '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] write: src_file.rs \(1 lines\)$' "${PLAN_DIR_T9}/progress.md" \
    && ok "9g post: line in plan progress.md" || bad "9g post: line in plan progress.md" "no hook log line in plan dir"
[ ! -f progress.md ] && ok "9h post: no root progress.md" || bad "9h post: no root progress.md" "root progress.md created"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 10: enforce-2action — read counter increments, blocks at N_READ
# ---------------------------------------------------------------------------
mkdir -p t10 && cd t10 || exit 1
write_plan7
# Root task_plan.md (legacy). N_READ=2 → 2 reads allowed, 3rd blocked.
for i in 1 2; do
    OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE"); RC=$?
    [ "$RC" = "0" ] && ok "10a read $i: allowed" || bad "10a read $i: allowed" "exit $RC"
done
# Third read hits the threshold → block.
OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "10b read 3: blocked" || bad "10b read 3: blocked" "exit $RC"
assert_contains "10c block reason" "$OUT" "2-Action Rule"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 11: enforce-2action — write counter increments, blocks at N_WRITE
# ---------------------------------------------------------------------------
cd t10 || exit 1
rm -f .hook_state
# N_WRITE=2 → 2 writes allowed, 3rd blocked.
for i in 1 2; do
    OUT=$(N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE"); RC=$?
    [ "$RC" = "0" ] && ok "11a write $i: allowed" || bad "11a write $i: allowed" "exit $RC"
done
OUT=$(N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "11b write 3: blocked" || bad "11b write 3: blocked" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 12: enforce-2action — write to a planning file resets the counters
# ---------------------------------------------------------------------------
cd t10 || exit 1
rm -f .hook_state
# Fill the write budget to the edge (N_WRITE=2 → 1 write).
N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE" >/dev/null
# A write to findings.md resets → the next non-planning write is allowed.
N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"findings.md"}' sh "$ENFORCE" >/dev/null
OUT=$(N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "0" ] && ok "12a planning write reset: next write allowed" || bad "12a planning write reset: next write allowed" "exit $RC: $OUT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 13: enforce-2action — read of a planning file neither counts nor resets
# ---------------------------------------------------------------------------
cd t10 || exit 1
rm -f .hook_state
# N_READ=2: two non-planning reads reach the budget; a planning read in
# between must not count.
N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE" >/dev/null
N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"task_plan.md"}' sh "$ENFORCE" >/dev/null
N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" >/dev/null
# Next non-planning read → at threshold → block (the planning read didn't count).
OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/c.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "13a planning read no count: blocked" || bad "13a planning read no count: blocked" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 14: enforce-2action — fail-open on corrupt state
# ---------------------------------------------------------------------------
cd t10 || exit 1
printf 'garbage not a counter\n' > .hook_state
OUT=$(N_READ=1 N_WRITE=1 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE" 2>&1); RC=$?
# Corrupt state → treated as zeroed → the read is allowed (fail-open).
[ "$RC" = "0" ] && ok "14a corrupt state: fail-open" || bad "14a corrupt state: fail-open" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 15: enforce-2action — no active plan → no-op
# ---------------------------------------------------------------------------
mkdir -p t15 && cd t15 || exit 1
OUT=$(N_READ=1 N_WRITE=1 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "0" ] && [ -z "$OUT" ] && ok "15a no plan: no-op" || bad "15a no plan: no-op" "exit $RC out=$OUT"
[ ! -f .hook_state ] && ok "15b no plan: no state file" || bad "15b no plan: no state file" "state file created"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 16: enforce-2action — bash read-like counts, other bash does not
# ---------------------------------------------------------------------------
cd t10 || exit 1
rm -f .hook_state
# N_READ=2: two read-like bashes reach the budget; other bash in between must
# not count.
N_READ=2 N_WRITE=9 TOOL_NAME=bash TOOL_INPUT='{"command":"grep foo src/a.rs"}' sh "$ENFORCE" >/dev/null
N_READ=2 N_WRITE=9 TOOL_NAME=bash TOOL_INPUT='{"command":"cargo build"}' sh "$ENFORCE" >/dev/null
N_READ=2 N_WRITE=9 TOOL_NAME=bash TOOL_INPUT='{"command":"rg bar src/"}' sh "$ENFORCE" >/dev/null
# Next read-like bash → at threshold → block (the other bash didn't count).
OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=bash TOOL_INPUT='{"command":"find src -name *.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "16a bash read-like counts: blocked" || bad "16a bash read-like counts: blocked" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 17: enforce-2action — bash writing to a planning file resets
# ---------------------------------------------------------------------------
cd t10 || exit 1
rm -f .hook_state
N_READ=9 N_WRITE=2 TOOL_NAME=bash TOOL_INPUT='{"command":"echo x > src/a.rs"}' sh "$ENFORCE" >/dev/null
N_READ=9 N_WRITE=2 TOOL_NAME=bash TOOL_INPUT='{"command":"echo note >> findings.md"}' sh "$ENFORCE" >/dev/null
OUT=$(N_READ=9 N_WRITE=2 TOOL_NAME=bash TOOL_INPUT='{"command":"echo y > src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "0" ] && ok "17a bash planning write reset: allowed" || bad "17a bash planning write reset: allowed" "exit $RC: $OUT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 18: log-compact appends a line to progress.md
# ---------------------------------------------------------------------------
cd t10 || exit 1
printf '# Progress Log\n\n## Session: 2026-10-24\n' > progress.md
OUT=$(COMPACT_TRIGGER=manual COMPACT_MESSAGES_REMOVED=42 sh "$LOGC")
[ -z "$OUT" ] && ok "18a log-compact: silent" || bad "18a log-compact: silent" "output: $OUT"
grep -q '^## Compactions' progress.md && ok "18b compactions section" || bad "18b compactions section" "no ## Compactions heading"
grep -qE '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] compaction 1 \(manual\): 42 messages removed' progress.md \
    && ok "18c compaction line" || bad "18c compaction line" "no compaction line"
OUT=$(COMPACT_TRIGGER=auto COMPACT_MESSAGES_REMOVED=10 sh "$LOGC")
grep -qE 'compaction 2 \(auto\): 10 messages removed' progress.md \
    && ok "18d second compaction ordinal" || bad "18d second compaction ordinal" "no ordinal 2"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 19: log-compact — no plan → no-op
# ---------------------------------------------------------------------------
mkdir -p t19 && cd t19 || exit 1
OUT=$(COMPACT_TRIGGER=auto sh "$LOGC")
[ -z "$OUT" ] && ok "19a no plan: log-compact no-op" || bad "19a no plan: log-compact no-op" "output: $OUT"
[ ! -f progress.md ] && ok "19b no plan: no progress.md" || bad "19b no plan: no progress.md" "progress.md created"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "================================"
echo "PASS: $PASS   FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "Failed tests:$FAILED_NAMES"
    exit 1
fi
echo "ALL TESTS PASSED"
exit 0
