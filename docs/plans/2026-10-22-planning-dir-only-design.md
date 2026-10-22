# Design: planning-with-files — always use `.planning/`, never the project root

- **Date:** 2026-10-22
- **Status:** Validated (all sections approved by user)
- **Skill:** `planning-with-files`
- **Supersedes nothing** — companion to `2026-10-22-planning-with-files-local-llm-fixes-design.md`

## Problem

The skill sometimes creates its planning files in the project root and sometimes in
`.planning/<date>-<slug>/`. The user wants the `.planning/` approach used *always*, so
planning files never land in the project root.

### Root cause (verified in code)

A prompt-level inconsistency, not a script bug:

1. **Project root (the common case):** the primary documented flow in `SKILL.md`
   (Quick Start) instructs the model to *hand-create* `task_plan.md`, `findings.md`,
   `progress.md` in the project root with the `write` tool. The model rarely runs
   `init-session.sh` at all.
2. **`.planning/<date>-<slug>/`:** only used when the model runs
   `init-session.sh "Task Name"` — a secondary "parallel task workflow" feature the
   primary flow never points to.
3. `resolve-plan-dir.sh` checks `$PLAN_ID` → `.planning/.active_plan` → newest
   `.planning/` dir → root `task_plan.md` (legacy fallback). Root files keep working,
   which reinforces the root habit.

## Decisions (user-approved)

| # | Question | Decision |
|---|----------|----------|
| 1 | Aggressiveness | **A.** Prompt-only + close the creation path. Keep the resolver's root fallback so existing projects keep working. No migration helper. |
| 2 | `init-session.sh` no-arg | **A.** Behaves like `--plan-dir`: creates `.planning/YYYY-MM-DD-untitled-<uuid>/` and pins `.active_plan`. The script has no code path that writes to the root. |
| 3 | Plan discovery at session start | **A.** Model runs `sh scripts/resolve-plan-dir.sh` and reads from the printed dir; empty output → start a new plan. Model and hooks share one source of truth. |
| 4 | "Read the templates first" step | **A.** Dropped as a hard step — `init-session.sh` owns file creation and enforces structure. `templates/` stays as reference; one fallback sentence covers a plan dir with a missing file. |
| 5 | Testing | **A.** Add fixture group 11 covering the `.planning/` flow end-to-end; keep existing root-based fixtures (they cover the retained legacy fallback). |

## Section 1: Scope and `init-session.sh` change

**Goal:** the skill never places planning files in the project root again;
`.planning/<date>-<slug>/` is the only creation path. Existing root plans keep
working via the resolver's legacy fallback (no migration, no fallback removal).

**Script change — `scripts/init-session.sh` (the only script modified):**

- Delete the legacy branch entirely (the `else` that calls `create_files_in "$(pwd)"`).
- No-arg invocation now behaves like `--plan-dir`: slug falls back to
  `untitled-<short-uuid>`, so `./init-session.sh` creates
  `.planning/YYYY-MM-DD-untitled-<uuid>/` and pins `.planning/.active_plan`.
- The `--plan-dir` flag becomes a no-op alias (kept so existing muscle memory / docs
  don't break); usage comment updated.
- `create_files_in`, slug mode, analytics template, and `.active_plan` pinning:
  unchanged.

**Unchanged:** `resolve-plan-dir.sh` (its 4th fallback step — root `task_plan.md` —
stays, so legacy projects keep hook support), all hook scripts, `attest-plan.sh`,
`check-complete.sh`, `gate-stop.sh`, `set-active-plan.sh`, templates.

**Net effect:** after this change, the only ways planning files appear are
(a) `init-session.sh` under `.planning/`, or (b) a model hand-writing them — which
the prompt in Section 2 forbids.

## Section 2: SKILL.md prompt rewrite

Five targeted edits, all in existing sections:

1. **"FIRST: Restore Context"** — replace the root-centric check with the resolver:
   - Run `sh scripts/resolve-plan-dir.sh`. If it prints a directory → read
     `task_plan.md`, `progress.md`, `findings.md` from it. If it prints nothing → no
     plan exists; start one (Quick Start).
   - Keep the existing "resuming after a gap → `git diff --stat`" step.
   - Add: "Planning files live in `.planning/<date>-<slug>/` (or a legacy project
     root). Never create them by hand — `init-session.sh` owns file creation."
2. **"Important: Where Files Go"** — table row "Your project directory" →
   "`.planning/<date>-<slug>/` in your project". The note becomes: "Planning files go
   in `.planning/` inside your project, never in the project root and never in the
   skill folder."
3. **Quick Start** — the hand-creation flow (read templates → create the three files)
   is replaced by:
   1. Run `sh scripts/init-session.sh "Task Name"` — creates
      `.planning/YYYY-MM-DD-<slug>/` with all three files and pins
      `.planning/.active_plan`.
   2. Read the three files from the printed `PLAN_ID` dir.
   3. Fallback sentence: "If a plan dir exists but a file is missing, read the
      matching `templates/*.md` and recreate it with the exact structure."
   - "Re-read plan before decisions" and "Update after each phase" steps stay.
4. **"Parallel task workflow"** — promoted from a secondary feature to the standard
   multi-task note: it no longer reads as an alternative to the root flow; the root
   flow no longer exists. Wording trimmed, `set-active-plan.sh` / `PLAN_ID` content
   unchanged.
5. **Scripts section** — `init-session.sh` description updated: "With a name arg,
   creates an isolated plan under `.planning/YYYY-MM-DD-<slug>/`. Without args,
   creates `.planning/YYYY-MM-DD-untitled-<uuid>/`. Never writes to the project
   root." `resolve-plan-dir.sh` description keeps the legacy-root fallback
   documented.

No changes to Critical Rules, PHASE GATE, security boundary, or frontmatter.

## Section 3: Skill README and tests

**`planning-with-files/README.md`** (the skill's own):

- Usage section: the "create planning files" instructions change from root-level to
  the `init-session.sh` flow; the "parallel task workflow" content merges into the
  main usage (it's no longer a separate mode).
- File structure section: planning files shown under `.planning/<date>-<slug>/`,
  with a note that legacy projects may have them in the root (hooks still support
  that).
- Scripts table: `init-session.sh` row updated (no root mode; no-arg → `untitled-*`).
- No changes to hook table, attestation, or install sections.

**`scripts/test-hooks.sh`** — new fixture group 11 (existing 29 assertions
untouched):

- 11a: `init-session.sh "Acme CLI"` in scratch dir → `.planning/<date>-acme-cli/`
  exists with all three files; `.planning/.active_plan` contains the plan id; no
  `task_plan.md` in the scratch root.
- 11b: `resolve-plan-dir.sh` prints the plan dir.
- 11c: `inject-plan.sh --context=pretool` emits the plan (smart head from the
  script-generated template).
- 11d: `post-tool-use.sh` with a `write` → mechanical line lands in
  `.planning/<...>/progress.md`, not in any root file.
- 11e: no-arg `init-session.sh` in a second scratch dir → `untitled-*` dir created,
  root stays clean.

That's ~5 new assertions → 34 total. Root-based fixtures 1–10 remain, still covering
the legacy fallback.

**Not changed:** root `README.md` (its planning-with-files row stays accurate),
`templates/` (reference only), all other scripts.

## Section 4: Verification and delivery

**Verification:**

1. `sh scripts/test-hooks.sh` — all 34 assertions pass (29 existing + 5 new), exit 0.
2. Manual smoke in a scratch project: `init-session.sh "Demo Task"` → files under
   `.planning/`, root untouched; `init-session.sh` (no arg) → `untitled-*` dir;
   `resolve-plan-dir.sh` returns the right dir in both cases; `bash -n` on the
   modified script.
3. Legacy check: a scratch dir with only a root `task_plan.md` (no `.planning/`) →
   hooks still resolve it (fallback intact).
4. This repo: root planning files keep working (hooks keep injecting).
5. Re-sync live skill dir (`rm -rf` + `cp -a`, `diff -rq` → SYNC OK), re-run tests
   from the live copy.

**Files touched:**

| File | Change |
|---|---|
| `planning-with-files/scripts/init-session.sh` | legacy branch removed; no-arg → `untitled-*` plan dir |
| `planning-with-files/SKILL.md` | 5 prompt edits (Section 2) |
| `planning-with-files/README.md` | usage/file-structure/scripts updates |
| `planning-with-files/scripts/test-hooks.sh` | fixture group 11 |
| `docs/plans/2026-10-22-planning-dir-only-design.md` | this design doc |

**Commit:** one commit — skill changes + design doc; planning files stay untracked
as session artifacts.

**Known limitation:** existing projects with root planning files (including this
repo) keep working but won't be migrated; the prompt never points the model at root
files it didn't already have. A migration helper remains a possible follow-up if
needed.
