# Design: `planning-with-files` — Remove superseded hooks, reintroduce Stop gate

- **Date:** 2026-10-25
- **Status:** Validated (all sections approved by user)
- **Location of work:** `agentskills/planning-with-files/`
- **Live skill dir:** `~/.config/respondami/skills/planning-with-files/` (re-synced after changes)
- **Context:** The hooks-simplification rework (2026-10-24) made `enforce-2action.sh`
  (PreToolUse) the primary mechanism for keeping `progress.md`/`findings.md` current.
  The PostToolUse mechanical log and the PostCompact compaction log are no longer
  needed. The Stop hook was removed earlier as a pure side effect; the new
  blocked-hook channel (exit 2 → stderr fed back as a new turn) makes it useful
  again as a completion gate.

## Section 1: Hook removals (PostToolUse + PostCompact)

Remove the two hooks that are superseded by `enforce-2action.sh`:

- **SKILL.md frontmatter:**
  - Remove the `PostToolUse` entry (matcher `Write|Edit` → `post-tool-use.sh`)
  - Remove the `PostCompact` entry (matcher `*` → `log-compact.sh`)
- **Script files:**
  - Delete `scripts/post-tool-use.sh`
  - Delete `scripts/log-compact.sh`
- **`test-hooks.sh`:**
  - Remove tests 5–9 (post-tool-use: mechanical line, loop guard, no-plan, section creation, .planning/ flow)
  - Remove tests 18–19 (log-compact: append line, no-plan)
  - Renumber remaining tests
- **`templates/progress.md`:**
  - Remove the `## Hook Log` section — it was maintained by the post-tool-use hook; with the hook gone, the section is dead weight. The model's descriptive entries in the phase sections remain the sole progress log.
- **SKILL.md "Respondami notes":**
  - Remove the "Mechanical progress log (PostToolUse)" bullet
  - Remove the "Compaction log (PostCompact)" bullet
  - Update the intro line: the hook set is now 3 events (PreToolUse veto, PreCompact injection, Stop veto)

## Section 2: Stop hook reintroduction (completion gate)

Reintroduce the Stop hook using the new blocked-hook channel: it vetoes the stop when the plan is incomplete, feeding a concrete reason back to the model as a new turn.

- **`check-complete.sh`** — add a `--strict` flag:
  - Without the flag: unchanged (always exit 0, status on stdout) — stays a usable manual utility
  - With `--strict`: exit 0 if all phases complete (or no plan exists), exit 1 if any phase is `in_progress` or `pending`
  - Status message format unchanged; `gate-stop.sh` reuses the same "N/M phases complete" wording for its block reason
- **`gate-stop.sh`** — rewritten:
  - Runs `check-complete.sh --strict`
  - Exit 0 → allow stop (plan complete, or no plan)
  - Exit 1 → `exit 2` with stderr: `Plan incomplete: N/M phases complete (X in progress, Y pending). Finish the current phase, update task_plan.md and progress.md, then stop.`
  - No active plan → exit 0 (never block a stop in a project without a plan)
  - The script header comment is updated: it is no longer advisory-only
- **SKILL.md frontmatter** — add back:
  ```yaml
  Stop:
    - hooks:
        - type: command
          command: "SKILL_DIR=\"${SKILL_DIR:-/home/dev/.config/respondami/skills/planning-with-files}\"; if [ -f \"${SKILL_DIR}/scripts/gate-stop.sh\" ]; then sh \"${SKILL_DIR}/scripts/gate-stop.sh\"; else exit 0; fi"
  ```
  Same if-else form as the PreToolUse hook so the exit 2 propagates (the `; exit 0` form was the bug fixed in `5c99db6`).
- **`test-hooks.sh`** — new tests:
  - All phases complete → exit 0, no stderr
  - Incomplete plan → exit 2, stderr contains "Plan incomplete"
  - No plan → exit 0 (no-op)
  - `check-complete.sh --strict`: complete → 0, incomplete → 1, no plan → 0
  - `check-complete.sh` without flag: incomplete → still exit 0 (manual mode unchanged)

## Section 3: Documentation updates

Bring the docs in line with the new 3-hook set.

- **SKILL.md "Respondami notes":**
  - Add a new bullet for the Stop gate: "at turn end, if the active plan has incomplete phases, the stop is vetoed (exit 2) with a concrete reason — the model must finish the current phase and update the planning files before it can stop. No plan → no veto."
  - Keep the existing 2-Action Rule and PreCompact bullets unchanged.
- **SKILL.md Scripts section:**
  - Remove the `post-tool-use.sh` and `log-compact.sh` entries from "Hook scripts"
  - Update the `gate-stop.sh` entry (currently missing from the list entirely): "Stop hook. Vetoes the stop while the active plan is incomplete; runs `check-complete.sh --strict` and exits 2 with a completion status reason."
  - Update the `check-complete.sh` entry: add the `--strict` flag to its description.
- **README.md:**
  - The hook table is stale (still lists `UserPromptSubmit`, per-tool `PreToolUse` injection, `Stop` advisory). Replace it with the current 3-hook set: `PreToolUse` (2-Action veto), `PreCompact` (plan injection into summary), `Stop` (completion gate)
  - Update the "five hooks" wording to "three hooks"
  - Scripts list: no change needed (already lists `check-complete.sh`, doesn't list the hook scripts)
- **Verification:**
  - `sh scripts/test-hooks.sh` passes (reduced + new tests)
  - Re-sync `agentskills/planning-with-files/` → `~/.config/respondami/skills/planning-with-files/`
  - Manual E2E: mid-task stop attempt → model receives the "Plan incomplete" turn and continues; after all phases complete → stop is allowed
  - Commit via caveman-commit
