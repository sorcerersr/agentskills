# Design: Other-Skill Hooks — `refine` + `code-health-check`/`arch-review` PreCompact Re-emit

- **Date:** 2026-10-24
- **Status:** Validated (all sections approved by user)
- **Location of work:** `agentskills/refine/`, `agentskills/code-health-check/`, `agentskills/arch-review/`
- **Depends on:** `respondami/docs/plans/2026-10-24-hooks-simplification-design.md`
  (the marker-based VCC preservation + model-A hook channel must land first)

## Purpose

Two skills produce long, in-progress artifacts that live in the conversation
until the end of the task:

- **`refine`** — the design, section by section, until all are approved.
- **`code-health-check` / `arch-review`** — the findings report, finding by
  finding, across three passes.

If a compaction fires mid-task, the in-progress artifact is lost from context
and the model re-does the work (the same analyze/compaction loop the
hooks-simplification design broke for planning-with-files). The fix is the same
pattern: persist the artifact to a file as it's produced, and have a `PreCompact`
hook re-emit it (marker-wrapped) so the VCC merge carries it through compaction
verbatim.

## Scope

- **In:** archiving the current (pre-modification) state of the three skills to a
  top-level `archive/` dir; `refine` PreCompact hook + incremental draft writing;
  `code-health-check`/`arch-review` PreCompact hook + incremental report
  writing; a shared `precompact-emit.sh` script.
- **Out:** `caveman-commit` (dropped — the skill doesn't run `git commit`, so a
  commit-scope veto isn't tied to it); any respondami engine changes (the
  marker-based VCC preservation and model-A channel are prerequisites, not part
  of this work); a `PostToolUse` durability floor for the review skills
  (rejected — the findings are already in the file; the `PreCompact` re-emit is
  the mechanism that preserves them).

## Validated decisions

| # | Decision | Choice |
| --- | --- | --- |
| 1 | `caveman-commit` hook | Dropped (skill doesn't run `git commit`) |
| 2 | Review-skill mechanism | `PreCompact` re-emit (not `PostToolUse`); skill writes findings incrementally |
| 3 | `refine` draft strategy | Separate `*.draft.md` file during brainstorming; rename to final on completion |
| 4 | Draft resolution | `.active_draft` state file (pinned path, no mtime scan) |
| 5 | Report resolution | `.active_report` state file (pinned path) |
| 6 | Marker | Reuse `===BEGIN PLAN DATA===` / `===END PLAN DATA===` (no new marker) |
| 7 | Shared script | One `precompact-emit.sh` used by all three skills (state-file path as arg) |
| 8 | Archive of pre-modification state | Top-level `archive/<skill>/` (one-time, no date, committed) |

## Shared mechanism

Each skill:

1. Persists its in-progress artifact to a file **as it's produced**.
2. Pins the file's relative path in a dot-file state file in its output dir.
3. Declares a `PreCompact` hook that runs `precompact-emit.sh <state-file>`.

`precompact-emit.sh`:

- Reads the state file (single line: relative path to the active file).
- If the state file is missing or the path doesn't resolve → silent `exit 0`
  (no-op, fail-open).
- Otherwise emits:
  ```
  ===BEGIN PLAN DATA===
  <file content, verbatim>
  ===END PLAN DATA===
  ```

The VCC merge (hooks-simplification design, Section 3) carries the marked block
through compaction verbatim. No new respondami engine feature is needed.

## Section 0: archive (first step, before any skill modification)

The user sometimes uses these skills in other harnesses (not respondami). After
this task the skills contain respondami-specific instructions (the `hooks:`
frontmatter, the `${SKILL_DIR}` command form, the incremental-write process). The
pre-modification state is the harness-agnostic version. Rather than digging
through git for it, archive it once, up front, in a top-level dir that is **not**
inside any skill dir (so it is not pulled into the respondami container and
duplicated there).

```
agentskills/
└── archive/
    ├── README.md               # what this is + why
    ├── refine/
    ├── code-health-check/
    └── arch-review/
```

- Each `archive/<skill>/` is a full copy of the skill dir's current state (all
  files: `SKILL.md`, `scripts/`, `templates/`, etc.).
- One-time operation — no date subdirectory.
- Committed to git (readily available, not just in history).
- `archive/README.md`: one short paragraph — these are the pre-respondami-specific
  versions of the skills, archived before the PreCompact hook work, for use in
  other harnesses.

## Section A: `refine`

**Skill process change** (`SKILL.md`):

- After the **first approved section**, create
  `docs/plans/YYYY-MM-DD-<topic>-design.draft.md`, write the section, and write
  the draft's relative path to `docs/plans/.active_draft`.
- After each **subsequent approved section**, append to the draft.
- On **completion** (all sections approved), rename the draft to
  `docs/plans/YYYY-MM-DD-<topic>-design.md` and clear `.active_draft`.

**Hook** (`SKILL.md` frontmatter):

```yaml
hooks:
  PreCompact:
    - hooks:
        - type: command
          command: sh ${SKILL_DIR}/scripts/precompact-emit.sh docs/plans/.active_draft
```

**Why it breaks the loss:** a long brainstorming session that triggers
compaction re-injects the draft into the compaction summary; the model resumes
with the full design context. The draft is also visible to the user.

**Edge cases:**

- Multiple drafts: `.active_draft` pins the current one; older drafts stay.
- Renamed to final: `.active_draft` cleared → hook no-ops.
- Compaction after completion: no `.active_draft` → no-op.

## Section B: `code-health-check` / `arch-review`

**Skill process change** (`SKILL.md`, both skills):

- At the **start** (after Pass 0), create
  `docs/reviews/YYYY-MM-DD-code-review.md` (arch-review:
  `YYYY-MM-DD-arch-review.md`) with the header, and write the path to
  `docs/reviews/.active_report`.
- As each **finding is generated**, append it to the report in the finding
  format.
- On **completion**, finalize the report (summary table, dependency audit) and
  clear `.active_report`.

**Hook** (`SKILL.md` frontmatter, both skills):

```yaml
hooks:
  PreCompact:
    - hooks:
        - type: command
          command: sh ${SKILL_DIR}/scripts/precompact-emit.sh docs/reviews/.active_report
```

**Why it breaks the loss:** a long review session that triggers compaction
re-injects the report into the compaction summary; the model resumes with the
full findings context and doesn't re-review files it already covered.

**Edge cases:**

- Report spans days: `.active_report` pins the current report; the filename
  date is set at creation.
- Review complete: `.active_report` cleared → hook no-ops.
- Multiple reviews: `.active_report` pins the current one; older reports stay.

## Section C: shared script

`precompact-emit.sh` (one copy per skill's `scripts/` dir, identical content):

```sh
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
```

- Fail-open: missing state file or unresolvable path → silent `exit 0`.
- The marker is the same one planning-with-files uses; the VCC merge rule is
  general.

## Section D: files changed

```
agentskills/
├── archive/                    # new (Section 0)
│   ├── README.md
│   ├── refine/                 # full copy of pre-modification state
│   ├── code-health-check/
│   └── arch-review/
├── refine/
│   ├── SKILL.md                # frontmatter hook + incremental draft process
│   └── scripts/
│       └── precompact-emit.sh  # new (shared script)
├── code-health-check/
│   ├── SKILL.md                # frontmatter hook + incremental report process
│   └── scripts/
│       └── precompact-emit.sh  # new (shared script)
└── arch-review/
    ├── SKILL.md                # frontmatter hook + incremental report process
    └── scripts/
        └── precompact-emit.sh  # new (shared script)
```

Re-sync each skill dir → `~/.config/respondami/skills/<skill>/` after the change.

## Section E: verification

Per-skill shell tests (a `test-hooks.sh` in each skill, or a shared test):

1. `precompact-emit.sh` with a valid state file → output contains the file
   content between the BEGIN/END markers.
2. `precompact-emit.sh` with a missing state file → empty output, exit 0.
3. `precompact-emit.sh` with a state file pointing to a missing file → empty
   output, exit 0.
4. `refine`: after the first approved section, the draft file exists and
   `.active_draft` is set; after completion, the draft is renamed and
   `.active_draft` is cleared.
5. `code-health-check`/`arch-review`: after Pass 0, the report file exists and
   `.active_report` is set; after completion, `.active_report` is cleared.

Manual E2E checklist (real session, local LLM):

- Start a `refine` brainstorming session; force a compaction mid-session → the
  compaction summary contains the draft between the markers; the model resumes
  with the full design context.
- Start a `code-health-check` review; force a compaction mid-review → the
  compaction summary contains the report between the markers; the model resumes
  without re-reviewing covered files.

Delivery: run test scripts, re-sync live skill dirs, commit (caveman-commit).

## Out of scope (YAGNI)

- `caveman-commit` hook (dropped — see Scope).
- Any respondami engine changes (prerequisites, not part of this work).
- A `PostToolUse` durability floor for the review skills (rejected — the
  `PreCompact` re-emit is the mechanism).
- `SessionStart`/`SessionEnd`/`Notification`/`SubagentStop` hook types
  (deferred).
- Claude Code's rich JSON hook output (deferred).
