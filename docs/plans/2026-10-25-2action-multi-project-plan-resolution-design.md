# 2-Action Hook: Multi-Project Plan Resolution

## Problem

The `enforce-2action.sh` PreToolUse hook (and the other planning hooks) resolve the
active plan via `resolve-plan-dir.sh`, which only looks in the CWD's `.planning/`
(`PLAN_ROOT="${1:-${PWD}/.planning}"`). When respondami is launched from a common
parent directory that spans multiple projects (each its own git repo), the CWD has
no `.planning/`. The plan lives in a project subdirectory, so the resolver finds
nothing, the hook no-ops (exit 0), the `.hook_state` counter file is never created,
and the 2-Action Rule never blocks. The counting logic itself is sound; plan
*discovery* is broken for the multi-project layout.

Two launch use cases:
- **Single project:** CWD is the project dir (usually a git repo). Works today.
- **Multi-project:** CWD is the common parent of several project repos. Broken.

## Design

### Resolution algorithm

`resolve-plan-dir.sh` resolution order becomes:

1. `$PLAN_ID` env → `./.planning/$PLAN_ID/` (unchanged)
2. `./.planning/.active_plan` → matching dir (unchanged)
3. Newest `./.planning/<dir>/` by mtime (unchanged)
4. **NEW:** scan immediate subdirectories of the CWD for a `*/.planning/` that
   contains a valid plan; pick the plan with the most recent activity
5. Empty (unchanged)

Step 4 only fires when steps 1–3 find nothing in the CWD, so the single-project
case is completely unaffected. For each candidate subdir, it resolves that
subdir's plan using the same active-file-then-latest logic, then picks the winner
by recency.

Details:
- **Depth:** immediate subdirs only (depth 1). The multi-project layout is exactly
  one level down; deeper scans risk slowness and picking up an unrelated nested
  repo's plan.
- **Hidden subdirs:** skipped (anything starting with `.`).
- **Recency signal:** the max mtime of the files *inside* the plan dir
  (`task_plan.md`, `findings.md`, `progress.md`, `.hook_state`), not the plan
  dir's own mtime. A dir's mtime only changes when entries are added/removed, not
  when a file is edited in place, so it is a weak signal. The max file mtime
  reflects the last real touch.
- **Tie-break:** if two subdirs' plans share the same max mtime, the one whose
  name sorts first wins (deterministic).

### Implementation

All changes are in `resolve-plan-dir.sh`. The existing helpers
(`slug_is_valid`, `mtime_of`) stay. The three resolvers are refactored to take a
plan-root argument so the same logic works for the CWD and for each subdir:

- `resolve_active <plan_root>` — reads `<plan_root>/.active_plan`, validates the
  slug, returns the dir if it exists.
- `resolve_latest <plan_root>` — the current newest-dir loop, but using the
  max-file-mtime signal.
- `resolve_in_root <plan_root>` — `resolve_active` then `resolve_latest`.
- `plan_activity <plan_dir>` — max mtime of the files inside the plan dir (glob
  `*` and `.*`, skipping `.`/`..`), via the existing portable `mtime_of`.
- `resolve_subdirs` — loops `"$PWD"/*/`, skips hidden, requires a `.planning/`,
  calls `resolve_in_root` on each, tracks the winner by `plan_activity` (tie →
  first slug alphabetically).

Main flow becomes:

```
1. $PLAN_ID valid  →  CWD .planning/$PLAN_ID          (unchanged)
2. resolve_in_root  CWD .planning                      (was steps 2+3)
3. resolve_subdirs                                        (new)
4. empty
```

Notes:
- `resolve_latest` now uses the max-file-mtime signal instead of the plan dir's
  mtime. This changes the CWD's `.planning/` resolution too, not just the subdir
  search — the same approved recency signal, applied consistently. Practical
  effect: a plan whose files were recently edited wins over one whose dir entry
  was merely touched.
- No interface change to callers. `enforce-2action.sh`, `inject-plan.sh`,
  `gate-stop.sh` all call `resolve-plan-dir.sh` with no args and read stdout, so
  they pick up the fix with zero changes. The optional `PLAN_ROOT` positional
  arg (used by tests) still works.

### Testing

New test groups in `test-hooks.sh` (which already builds temp-dir fixtures and
runs the resolver directly):

1. **Regression — single project:** CWD has `.planning/` with a plan → resolves
   it. (Existing tests already cover this; they must keep passing unchanged.)
2. **Multi-project, recency wins:** CWD has no `.planning/`; two subdirs each
   have a plan; one's files are newer → resolves the newer one.
3. **Multi-project, CWD plan takes precedence:** CWD has a plan *and* a subdir
   has a newer plan → resolves the CWD's plan (step 2 fires before step 3).
4. **Multi-project, active-file honored:** a subdir's `.planning/.active_plan`
   points to a valid plan → that plan resolves.
5. **Tie-break:** two subdir plans with identical max mtime → the
   alphabetically-first slug wins.
6. **Hidden subdir skipped:** a `./.hidden/.planning/` plan is never selected.
7. **Depth-1 only:** a plan two levels down (`a/b/.planning/`) is not found.
8. **No plan anywhere:** CWD and subdirs have no `.planning/` → empty stdout,
   exit 0.

File mtimes are set explicitly with `touch -d` so the recency and tie-break
tests are deterministic rather than timing-dependent. The existing
`enforce-2action` / `gate-stop` / `inject-plan` test groups stay as-is — they
exercise the resolver through the hooks and will now also implicitly cover the
multi-project path.
