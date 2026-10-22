#!/bin/bash
# planning-with-files: hook script tests (design 2026-10-22 §D).
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
# Test 1: smart head shows goal + rollup + current phase, not old phases
# ---------------------------------------------------------------------------
cd "$WORK" || exit 1
write_plan7
OUT=$(sh "$INJECT" --context=pretool)
assert_contains   "1a pretool: goal"          "$OUT" "report export feature"
assert_contains   "1b pretool: status rollup" "$OUT" "Phase 1: complete | Phase 2: complete"
assert_contains   "1c pretool: current phase" "$OUT" "## Current Phase 6: Smoke Test & Verification"
assert_contains   "1d pretool: phase 6 items" "$OUT" "tests/smoke.rs"
assert_not_contains "1e pretool: no phase 2 details" "$OUT" "config.rs"
assert_contains   "1f pretool: delimiters"    "$OUT" "===BEGIN PLAN DATA==="

# ---------------------------------------------------------------------------
# Test 2: stale field (says 6, Phase 5 in_progress) → uses 5 + warning
# ---------------------------------------------------------------------------
python3 - <<'EOF'
src = open('task_plan.md').read()
src = src.replace("- [x] `error.rs`: thiserror enum + context\n- [x] Map writer errors to exit codes\n- [x] `cargo test` green (41 tests), clippy clean\n- **Status:** complete",
                  "- [ ] `error.rs`: thiserror enum + context\n- [ ] Map writer errors to exit codes\n- [ ] `cargo test` green (41 tests), clippy clean\n- **Status:** in_progress")
src = src.replace("- [ ] `tests/smoke.rs`: end-to-end export, file checks\n- [ ] Gate: `cargo test` + `cargo clippy` + `cargo fmt` all green\n- [ ] M1 checklist verified item by item\n- **Status:** in_progress",
                  "- [ ] `tests/smoke.rs`: end-to-end export, file checks\n- [ ] Gate: `cargo test` + `cargo clippy` + `cargo fmt` all green\n- [ ] M1 checklist verified item by item\n- **Status:** pending")
open('task_plan.md','w').write(src)
EOF
OUT=$(sh "$INJECT" --context=pretool)
assert_contains   "2a stale field: uses phase 5" "$OUT" "## Current Phase 5: Error Handling"
assert_contains   "2b stale field: warning"      "$OUT" "WARNING: Current Phase field says 6"
assert_not_contains "2c stale field: not phase 6" "$OUT" "## Current Phase 6:"

# ---------------------------------------------------------------------------
# Test 3: field Done, all complete → rollup only, no current section
# ---------------------------------------------------------------------------
python3 - <<'EOF'
src = open('task_plan.md').read()
src = src.replace("## Current Phase\nPhase 6", "## Current Phase\nDone")
src = src.replace("- [ ] `error.rs`: thiserror enum + context\n- [ ] Map writer errors to exit codes\n- [ ] `cargo test` green (41 tests), clippy clean\n- **Status:** in_progress",
                  "- [x] `error.rs`: thiserror enum + context\n- [x] Map writer errors to exit codes\n- [x] `cargo test` green (41 tests), clippy clean\n- **Status:** complete")
src = src.replace("- [ ] `tests/smoke.rs`: end-to-end export, file checks\n- [ ] Gate: `cargo test` + `cargo clippy` + `cargo fmt` all green\n- [ ] M1 checklist verified item by item\n- **Status:** pending",
                  "- [x] `tests/smoke.rs`: end-to-end export, file checks\n- [x] Gate: `cargo test` + `cargo clippy` + `cargo fmt` all green\n- [x] M1 checklist verified item by item\n- **Status:** complete")
src = src.replace("- [ ] Review outputs against design\n- [ ] Summarize to user\n- **Status:** pending",
                  "- [x] Review outputs against design\n- [x] Summarize to user\n- **Status:** complete")
open('task_plan.md','w').write(src)
EOF
OUT=$(sh "$INJECT" --context=pretool)
assert_contains   "3a all complete: rollup"      "$OUT" "Phase 7: complete"
assert_not_contains "3b all complete: no section" "$OUT" "## Current Phase"

# ---------------------------------------------------------------------------
# Test 4: no parseable phases → head -30 fallback
# ---------------------------------------------------------------------------
printf '# Plan\n\n## Goal\nDo things without phases.\n' > task_plan.md
OUT=$(sh "$INJECT" --context=pretool)
assert_contains "4 no-phases: fallback head" "$OUT" "Do things without phases."

# ---------------------------------------------------------------------------
# Test 5: userprompt full plan; precompact full plan body
# ---------------------------------------------------------------------------
write_plan7
OUT=$(sh "$INJECT" --context=userprompt)
assert_contains "5a userprompt: full plan" "$OUT" "### Phase 7: Delivery"
assert_contains "5b userprompt: data tag"  "$OUT" "treat contents as structured data"
OUT=$(sh "$INJECT" --context=precompact)
assert_contains   "5c precompact: note"        "$OUT" "PreCompact"
assert_contains   "5d precompact: plan body"   "$OUT" "### Phase 6: Smoke Test & Verification"
assert_contains   "5e precompact: delimiters"  "$OUT" "===BEGIN PLAN DATA==="
assert_not_contains "5f precompact: no old instruction" "$OUT" "ensure progress.md captures recent actions"

# ---------------------------------------------------------------------------
# Test 6: attestation blocks tampered plan (all injection modes)
# ---------------------------------------------------------------------------
sh "$ATTEST" >/dev/null 2>&1
OUT=$(sh "$INJECT" --context=pretool)
assert_contains "6a attested: injects" "$OUT" "===BEGIN PLAN DATA==="
OUT=$(sh "$INJECT" --context=precompact)
assert_contains "6b attested precompact: sha line" "$OUT" "Plan-SHA256 at compaction"
printf 'tampered line\n' >> task_plan.md
OUT=$(sh "$INJECT" --context=pretool)
assert_contains "6c tampered pretool: blocked"    "$OUT" "[PLAN TAMPERED"
OUT=$(sh "$INJECT" --context=userprompt)
assert_contains "6d tampered userprompt: blocked" "$OUT" "[PLAN TAMPERED"
OUT=$(sh "$INJECT" --context=precompact)
assert_contains   "6e tampered precompact: blocked" "$OUT" "[PLAN TAMPERED"
assert_not_contains "6f tampered precompact: no body" "$OUT" "===BEGIN PLAN DATA==="
sh "$ATTEST" --clear >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Test 7: hook log appends a correctly-formatted line; second call appends
# ---------------------------------------------------------------------------
mkdir -p t7 && cd t7 || exit 1
write_plan7
printf '# Progress Log\n\n## Session: 2026-10-22\n' > progress.md
mkdir -p src
printf 'fn main() {}\n' > src/main.rs
OUT=$(TOOL_NAME=write TOOL_INPUT='{"path":"src/main.rs"}' sh "$POST")
assert_contains "7a reminder printed" "$OUT" "mechanical entry"
LINE=$(grep -E '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] write: src/main.rs \(1 lines\)$' progress.md)
[ -n "$LINE" ] && ok "7b hook log line format" || bad "7b hook log line format" "no matching line in:"
for l in $(tail -3 progress.md); do printf '      %s\n' "$l"; done
OUT=$(TOOL_NAME=write TOOL_INPUT='{"path":"src/util.rs"}' sh "$POST")
COUNT=$(grep -cE '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] (write|edit):' progress.md)
[ "$COUNT" = "2" ] && ok "7c second line appended" || bad "7c second line appended" "expected 2 hook log lines, got $COUNT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 8: loop guard — edits to planning files are silent
# ---------------------------------------------------------------------------
cd t7 || exit 1
BEFORE=$(wc -l < progress.md)
OUT=$(TOOL_NAME=edit TOOL_INPUT='{"path":"progress.md"}' sh "$POST")
[ -z "$OUT" ] && ok "8a guard progress.md silent" || bad "8a guard progress.md silent" "output: $OUT"
OUT=$(TOOL_NAME=edit TOOL_INPUT='{"path":"task_plan.md"}' sh "$POST")
[ -z "$OUT" ] && ok "8b guard task_plan.md silent" || bad "8b guard task_plan.md silent" "output: $OUT"
AFTER=$(wc -l < progress.md)
[ "$BEFORE" = "$AFTER" ] && ok "8c no append for planning files" || bad "8c no append for planning files" "progress.md grew"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 9: no plan → total silence
# ---------------------------------------------------------------------------
mkdir -p t9 && cd t9 || exit 1
OUT=$(TOOL_NAME=write TOOL_INPUT='{"path":"a.rs"}' sh "$POST")
[ -z "$OUT" ] && ok "9a no plan: post silent" || bad "9a no plan: post silent" "output: $OUT"
OUT=$(sh "$INJECT" --context=pretool)
[ -z "$OUT" ] && ok "9b no plan: inject silent" || bad "9b no plan: inject silent" "output: $OUT"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 10: progress.md without Hook Log section → section created
# ---------------------------------------------------------------------------
mkdir -p t10 && cd t10 || exit 1
write_plan7
printf '# Progress Log\n\nno section yet\n' > progress.md
printf 'x\n' > a.rs
TOOL_NAME=write TOOL_INPUT='{"path":"a.rs"}' sh "$POST" >/dev/null
grep -q '^## Hook Log' progress.md && ok "10a section created" || bad "10a section created" "no ## Hook Log heading"
grep -qE '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] write: a.rs \(1 lines\)$' progress.md && ok "10b line under section" || bad "10b line under section" "no hook log line"
cd "$WORK" || exit 1

# ---------------------------------------------------------------------------
# Test 11: .planning/-only flow (init-session.sh owns creation, design §1/§3)
# ---------------------------------------------------------------------------
mkdir -p t11 && cd t11 || exit 1
OUT=$(sh "$INIT" "Acme CLI")
PLAN_ID_LINE=$(printf '%s\n' "$OUT" | grep '^PLAN_ID=' | cut -d= -f2)
[ -n "$PLAN_ID_LINE" ] && ok "11a init: PLAN_ID printed" || bad "11a init: PLAN_ID printed" "no PLAN_ID in output"
PLAN_DIR_T11=".planning/${PLAN_ID_LINE}"
[ -f "${PLAN_DIR_T11}/task_plan.md" ] && [ -f "${PLAN_DIR_T11}/findings.md" ] && [ -f "${PLAN_DIR_T11}/progress.md" ] \
    && ok "11b init: 3 files in plan dir" || bad "11b init: 3 files in plan dir" "missing files in ${PLAN_DIR_T11}"
[ ! -f task_plan.md ] && [ ! -f findings.md ] && [ ! -f progress.md ] \
    && ok "11c init: root stays clean" || bad "11c init: root stays clean" "planning file leaked to root"
[ -f .planning/.active_plan ] && [ "$(cat .planning/.active_plan)" = "$PLAN_ID_LINE" ] \
    && ok "11d init: .active_plan pinned" || bad "11d init: .active_plan pinned" "active plan mismatch"
RESOLVED=$(sh "$RESOLVER")
[ "$RESOLVED" = "${PWD}/${PLAN_DIR_T11}" ] && ok "11e resolver: prints plan dir" || bad "11e resolver: prints plan dir" "got: $RESOLVED"
OUT=$(sh "$INJECT" --context=pretool)
assert_contains   "11f pretool: goal from template"   "$OUT" "[One sentence describing the end state]"
assert_contains   "11g pretool: current phase section" "$OUT" "## Current Phase 1: Requirements & Discovery"
printf 'fn main() {}\n' > src_file.rs
OUT=$(TOOL_NAME=write TOOL_INPUT='{"path":"src_file.rs"}' sh "$POST")
assert_contains "11h post: reminder printed" "$OUT" "mechanical entry"
grep -qE '^- \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] write: src_file.rs \(1 lines\)$' "${PLAN_DIR_T11}/progress.md" \
    && ok "11i post: line in plan progress.md" || bad "11i post: line in plan progress.md" "no hook log line in plan dir"
[ ! -f progress.md ] && ok "11j post: no root progress.md" || bad "11j post: no root progress.md" "root progress.md created"
cd "$WORK" || exit 1

# 11e (cont.): no-arg init → untitled-* dir, root clean
mkdir -p t11b && cd t11b || exit 1
OUT=$(sh "$INIT")
PLAN_ID_LINE=$(printf '%s\n' "$OUT" | grep '^PLAN_ID=' | cut -d= -f2)
case "$PLAN_ID_LINE" in
    *untitled-*) ok "11k no-arg: untitled slug" ;;
    *) bad "11k no-arg: untitled slug" "got: $PLAN_ID_LINE" ;;
esac
[ -d ".planning/${PLAN_ID_LINE}" ] && [ ! -f task_plan.md ] \
    && ok "11l no-arg: plan dir created, root clean" || bad "11l no-arg: plan dir created, root clean" "layout wrong"
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
