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
ENFORCE="${SCRIPT_DIR}/enforce-2action.sh"
GATESTOP="${SCRIPT_DIR}/gate-stop.sh"
CHECK="${SCRIPT_DIR}/check-complete.sh"
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
# Test 5: .planning/-only flow (init-session.sh owns creation)
# ---------------------------------------------------------------------------
mkdir -p t5 && cd t5 || exit 1
OUT=$(sh "$INIT" "Acme CLI")
PLAN_ID_LINE=$(printf '%s\n' "$OUT" | grep '^PLAN_ID=' | cut -d= -f2)
[ -n "$PLAN_ID_LINE" ] && ok "5a init: PLAN_ID printed" || bad "5a init: PLAN_ID printed" "no PLAN_ID in output"
PLAN_DIR_T5=".planning/${PLAN_ID_LINE}"
[ -f "${PLAN_DIR_T5}/task_plan.md" ] && [ -f "${PLAN_DIR_T5}/findings.md" ] && [ -f "${PLAN_DIR_T5}/progress.md" ] \
    && ok "5b init: 3 files in plan dir" || bad "5b init: 3 files in plan dir" "missing files in ${PLAN_DIR_T5}"
[ ! -f task_plan.md ] && [ ! -f findings.md ] && [ ! -f progress.md ] \
    && ok "5c init: root stays clean" || bad "5c init: root stays clean" "planning file leaked to root"
[ -f .planning/.active_plan ] && [ "$(cat .planning/.active_plan)" = "$PLAN_ID_LINE" ] \
    && ok "5d init: .active_plan pinned" || bad "5d init: .active_plan pinned" "active plan mismatch"
RESOLVED=$(sh "$RESOLVER")
[ "$RESOLVED" = "${PWD}/${PLAN_DIR_T5}" ] && ok "5e resolver: prints plan dir" || bad "5e resolver: prints plan dir" "got: $RESOLVED"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 6: enforce-2action — read counter increments, blocks at N_READ
# ---------------------------------------------------------------------------
mkdir -p t6 && cd t6 || exit 1
write_plan7
# Root task_plan.md (legacy). N_READ=2 → 2 reads allowed, 3rd blocked.
for i in 1 2; do
    OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE"); RC=$?
    [ "$RC" = "0" ] && ok "6a read $i: allowed" || bad "6a read $i: allowed" "exit $RC"
done
# Third read hits the threshold → block.
OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "6b read 3: blocked" || bad "6b read 3: blocked" "exit $RC"
assert_contains "6c block reason" "$OUT" "2-Action Rule"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 7: enforce-2action — write counter increments, blocks at N_WRITE
# ---------------------------------------------------------------------------
cd t6 || exit 1
rm -f .hook_state
# N_WRITE=2 → 2 writes allowed, 3rd blocked.
for i in 1 2; do
    OUT=$(N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE"); RC=$?
    [ "$RC" = "0" ] && ok "7a write $i: allowed" || bad "7a write $i: allowed" "exit $RC"
done
OUT=$(N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "7b write 3: blocked" || bad "7b write 3: blocked" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 8: enforce-2action — write to a planning file resets the counters
# ---------------------------------------------------------------------------
cd t6 || exit 1
rm -f .hook_state
# Fill the write budget to the edge (N_WRITE=2 → 1 write).
N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE" >/dev/null
# A write to findings.md resets → the next non-planning write is allowed.
N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"findings.md"}' sh "$ENFORCE" >/dev/null
OUT=$(N_READ=9 N_WRITE=2 TOOL_NAME=write TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "0" ] && ok "8a planning write reset: next write allowed" || bad "8a planning write reset: next write allowed" "exit $RC: $OUT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 9: enforce-2action — read of a planning file neither counts nor resets
# ---------------------------------------------------------------------------
cd t6 || exit 1
rm -f .hook_state
# N_READ=2: two non-planning reads reach the budget; a planning read in
# between must not count.
N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE" >/dev/null
N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"task_plan.md"}' sh "$ENFORCE" >/dev/null
N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" >/dev/null
# Next non-planning read → at threshold → block (the planning read didn't count).
OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/c.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "9a planning read no count: blocked" || bad "9a planning read no count: blocked" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 10: enforce-2action — fail-open on corrupt state
# ---------------------------------------------------------------------------
cd t6 || exit 1
printf 'garbage not a counter\n' > .hook_state
OUT=$(N_READ=1 N_WRITE=1 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE" 2>&1); RC=$?
# Corrupt state → treated as zeroed → the read is allowed (fail-open).
[ "$RC" = "0" ] && ok "10a corrupt state: fail-open" || bad "10a corrupt state: fail-open" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 11: enforce-2action — no active plan → no-op
# ---------------------------------------------------------------------------
mkdir -p t11 && cd t11 || exit 1
OUT=$(N_READ=1 N_WRITE=1 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "0" ] && [ -z "$OUT" ] && ok "11a no plan: no-op" || bad "11a no plan: no-op" "exit $RC out=$OUT"
[ ! -f .hook_state ] && ok "11b no plan: no state file" || bad "11b no plan: no state file" "state file created"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 12: enforce-2action — bash read-like counts, other bash does not
# ---------------------------------------------------------------------------
cd t6 || exit 1
rm -f .hook_state
# N_READ=2: two read-like bashes reach the budget; other bash in between must
# not count.
N_READ=2 N_WRITE=9 TOOL_NAME=bash TOOL_INPUT='{"command":"grep foo src/a.rs"}' sh "$ENFORCE" >/dev/null
N_READ=2 N_WRITE=9 TOOL_NAME=bash TOOL_INPUT='{"command":"cargo build"}' sh "$ENFORCE" >/dev/null
N_READ=2 N_WRITE=9 TOOL_NAME=bash TOOL_INPUT='{"command":"rg bar src/"}' sh "$ENFORCE" >/dev/null
# Next read-like bash → at threshold → block (the other bash didn't count).
OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=bash TOOL_INPUT='{"command":"find src -name *.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "12a bash read-like counts: blocked" || bad "12a bash read-like counts: blocked" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 13: enforce-2action — bash writing to a planning file resets
# ---------------------------------------------------------------------------
cd t6 || exit 1
rm -f .hook_state
N_READ=9 N_WRITE=2 TOOL_NAME=bash TOOL_INPUT='{"command":"echo x > src/a.rs"}' sh "$ENFORCE" >/dev/null
N_READ=9 N_WRITE=2 TOOL_NAME=bash TOOL_INPUT='{"command":"echo note >> findings.md"}' sh "$ENFORCE" >/dev/null
OUT=$(N_READ=9 N_WRITE=2 TOOL_NAME=bash TOOL_INPUT='{"command":"echo y > src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "0" ] && ok "13a bash planning write reset: allowed" || bad "13a bash planning write reset: allowed" "exit $RC: $OUT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 14: check-complete.sh — manual mode always exits 0
# ---------------------------------------------------------------------------
mkdir -p t14 && cd t14 || exit 1
write_plan7
OUT=$(sh "$CHECK"); RC=$?
[ "$RC" = "0" ] && ok "14a manual: incomplete → exit 0" || bad "14a manual: incomplete → exit 0" "exit $RC"
assert_contains "14b manual: status line" "$OUT" "Task in progress"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 15: check-complete.sh --strict — exit codes
# ---------------------------------------------------------------------------
cd t14 || exit 1
OUT=$(sh "$CHECK" --strict); RC=$?
[ "$RC" = "1" ] && ok "15a strict: incomplete → exit 1" || bad "15a strict: incomplete → exit 1" "exit $RC"
# Mark all phases complete → strict exits 0.
sed -i 's/\*\*Status:\*\* in_progress/**Status:** complete/' task_plan.md
sed -i 's/\*\*Status:\*\* pending/**Status:** complete/' task_plan.md
OUT=$(sh "$CHECK" --strict); RC=$?
[ "$RC" = "0" ] && ok "15b strict: complete → exit 0" || bad "15b strict: complete → exit 0" "exit $RC"
[ -z "$OUT" ] && ok "15c strict: silent" || bad "15c strict: silent" "output: $OUT"
# No plan → strict exits 0 (nothing to check).
cd "$WORK" || exit 1
mkdir -p t15b && cd t15b || exit 1
OUT=$(sh "$CHECK" --strict); RC=$?
[ "$RC" = "0" ] && ok "15d strict: no plan → exit 0" || bad "15d strict: no plan → exit 0" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 16: gate-stop.sh — vetoes the stop while the plan is incomplete
# ---------------------------------------------------------------------------
mkdir -p t16 && cd t16 || exit 1
write_plan7
OUT=$(sh "$GATESTOP" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "16a gate: incomplete → exit 2" || bad "16a gate: incomplete → exit 2" "exit $RC"
assert_contains "16b gate: block reason" "$OUT" "Plan incomplete"
assert_contains "16c gate: phase count" "$OUT" "5/7 phases complete"
# Mark all phases complete → stop allowed.
sed -i 's/\*\*Status:\*\* in_progress/**Status:** complete/' task_plan.md
sed -i 's/\*\*Status:\*\* pending/**Status:** complete/' task_plan.md
OUT=$(sh "$GATESTOP" 2>&1); RC=$?
[ "$RC" = "0" ] && ok "16d gate: complete → exit 0" || bad "16d gate: complete → exit 0" "exit $RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 17: gate-stop.sh — no plan → no-op (exit 0)
# ---------------------------------------------------------------------------
mkdir -p t17 && cd t17 || exit 1
OUT=$(sh "$GATESTOP" 2>&1); RC=$?
[ "$RC" = "0" ] && [ -z "$OUT" ] && ok "17a gate: no plan → exit 0" || bad "17a gate: no plan → exit 0" "exit $RC out=$OUT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 18: resolver — single project (CWD .planning) regression
# ---------------------------------------------------------------------------
mkdir -p t18 && cd t18 || exit 1
mkdir -p .planning/2026-01-01-a
echo x > .planning/2026-01-01-a/task_plan.md
RESOLVED=$(sh "$RESOLVER")
[ "$RESOLVED" = "${PWD}/.planning/2026-01-01-a" ] && ok "18a single: CWD plan" || bad "18a single: CWD plan" "got: $RESOLVED"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 19: resolver — multi-project, recency wins
# ---------------------------------------------------------------------------
mkdir -p t19 && cd t19 || exit 1
mkdir -p projA/.planning/2026-01-01-a projB/.planning/2026-01-02-b
echo x > projA/.planning/2026-01-01-a/task_plan.md
echo x > projB/.planning/2026-01-02-b/task_plan.md
touch -d '2026-01-01 10:00' projA/.planning/2026-01-01-a/task_plan.md
touch -d '2026-01-02 10:00' projB/.planning/2026-01-02-b/task_plan.md
RESOLVED=$(sh "$RESOLVER")
[ "$RESOLVED" = "${PWD}/projB/.planning/2026-01-02-b" ] && ok "19a multi: recency wins" || bad "19a multi: recency wins" "got: $RESOLVED"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 20: resolver — multi-project, CWD plan takes precedence
# ---------------------------------------------------------------------------
cd t19 || exit 1
mkdir -p .planning/2026-01-01-c
echo x > .planning/2026-01-01-c/task_plan.md
touch -d '2026-01-01 09:00' .planning/2026-01-01-c/task_plan.md
RESOLVED=$(sh "$RESOLVER")
[ "$RESOLVED" = "${PWD}/.planning/2026-01-01-c" ] && ok "20a multi: CWD precedence" || bad "20a multi: CWD precedence" "got: $RESOLVED"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 21: resolver — multi-project, active-file honored
# ---------------------------------------------------------------------------
mkdir -p t21 && cd t21 || exit 1
mkdir -p projA/.planning/2026-01-01-a projA/.planning/2026-01-05-z
echo x > projA/.planning/2026-01-01-a/task_plan.md
echo x > projA/.planning/2026-01-05-z/task_plan.md
touch -d '2026-01-01 10:00' projA/.planning/2026-01-01-a/task_plan.md
touch -d '2026-01-05 10:00' projA/.planning/2026-01-05-z/task_plan.md
# .active_plan points to the older plan → it wins over recency.
printf '2026-01-01-a\n' > projA/.planning/.active_plan
RESOLVED=$(sh "$RESOLVER")
[ "$RESOLVED" = "${PWD}/projA/.planning/2026-01-01-a" ] && ok "21a multi: active-file honored" || bad "21a multi: active-file honored" "got: $RESOLVED"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 22: resolver — multi-project tie-break (same mtime → first slug)
# ---------------------------------------------------------------------------
mkdir -p t22 && cd t22 || exit 1
mkdir -p projB/.planning/2026-01-02-b projA/.planning/2026-01-01-a
echo x > projB/.planning/2026-01-02-b/task_plan.md
echo x > projA/.planning/2026-01-01-a/task_plan.md
touch -d '2026-01-01 10:00' projA/.planning/2026-01-01-a/task_plan.md projB/.planning/2026-01-02-b/task_plan.md
RESOLVED=$(sh "$RESOLVER")
[ "$RESOLVED" = "${PWD}/projA/.planning/2026-01-01-a" ] && ok "22a multi: tie-break first slug" || bad "22a multi: tie-break first slug" "got: $RESOLVED"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 23: resolver — hidden subdir skipped
# ---------------------------------------------------------------------------
mkdir -p t23 && cd t23 || exit 1
mkdir -p .hidden/.planning/2026-01-01-h
echo x > .hidden/.planning/2026-01-01-h/task_plan.md
RESOLVED=$(sh "$RESOLVER")
[ -z "$RESOLVED" ] && ok "23a multi: hidden subdir skipped" || bad "23a multi: hidden subdir skipped" "got: $RESOLVED"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 24: resolver — depth-1 only (a/b/.planning not found)
# ---------------------------------------------------------------------------
mkdir -p t24 && cd t24 || exit 1
mkdir -p a/b/.planning/2026-01-01-n
echo x > a/b/.planning/2026-01-01-n/task_plan.md
RESOLVED=$(sh "$RESOLVER")
[ -z "$RESOLVED" ] && ok "24a multi: depth-1 only" || bad "24a multi: depth-1 only" "got: $RESOLVED"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 25: resolver — no plan anywhere → empty, exit 0
# ---------------------------------------------------------------------------
mkdir -p t25 && cd t25 || exit 1
mkdir -p emptyproj
echo x > emptyproj/README.md
RESOLVED=$(sh "$RESOLVER"); RC=$?
[ -z "$RESOLVED" ] && [ "$RC" = "0" ] && ok "25a multi: no plan → empty" || bad "25a multi: no plan → empty" "got: $RESOLVED rc=$RC"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 26: enforce-2action — multi-project CWD now counts + blocks
# ---------------------------------------------------------------------------
mkdir -p t26 && cd t26 || exit 1
mkdir -p proj/.planning/2026-01-01-a
echo x > proj/.planning/2026-01-01-a/task_plan.md
# N_READ=2: two reads allowed, third blocked — via the subdir-resolved plan.
for i in 1 2; do
    OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/a.rs"}' sh "$ENFORCE"); RC=$?
    [ "$RC" = "0" ] && ok "26a multi enforce read $i: allowed" || bad "26a multi enforce read $i: allowed" "exit $RC"
done
OUT=$(N_READ=2 N_WRITE=9 TOOL_NAME=read TOOL_INPUT='{"path":"src/b.rs"}' sh "$ENFORCE" 2>&1); RC=$?
[ "$RC" = "2" ] && ok "26b multi enforce read 3: blocked" || bad "26b multi enforce read 3: blocked" "exit $RC"
assert_contains "26c multi enforce: block reason" "$OUT" "2-Action Rule"
[ -f proj/.planning/2026-01-01-a/.hook_state ] && ok "26d multi enforce: state file in project" || bad "26d multi enforce: state file in project" "no state file"
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
