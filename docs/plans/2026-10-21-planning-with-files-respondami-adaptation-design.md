# Design: `planning-with-files` skill — Respondami adaptation

- **Date:** 2026-10-21
- **Status:** Validated (all sections approved by user)
- **Location of work:** `agentskills/planning-with-files/`
- **Live skill dir:** `~/.config/respondami/skills/planning-with-files/` (re-synced after changes)
- **Dependency:** `respondami/docs/plans/2026-10-21-skill-hooks-design.md` must land first (Phase 1 there). This design's hook matchers and "Respondami notes" describe behavior that only exists after that core change.

## Purpose

The `planning-with-files` skill enforces Manus-style file-based planning:
`task_plan.md`, `findings.md`, `progress.md` are created up front in the
project directory and updated after every phase, so a session can be quit and
resumed with minimal friction. Its discipline depends on lifecycle hooks that
keep the plan in the model's attention window every turn.

Observed failure in Respondami: `progress.md`/`task_plan.md` are updated only
sporadically (sometimes just at task end), and the skill's template files are
never read. Two causes:

1. The skill's hooks were dead in Respondami (frontmatter `hooks:` ignored,
   hook output not injected into model context). Fixed by the companion
   Respondami core design — not by this one.
2. The skill prompt itself has gaps: template reading is a soft "as
   reference" link rather than a hard step, there is no explicit gate between
   phases, and the skill carries sections for features that do not exist in
   Respondami.

This design closes cause 2 and makes the skill's frontmatter use the new
`matcher` field.

## Current state of the skill (self-contained reference)

`SKILL.md` frontmatter declares five hooks (commands already adapted to
Respondami's env-var interface, self-guarding with `[ -f ... ]`):

| Event | Script | Behavior |
|-------|--------|----------|
| `UserPromptSubmit` | `scripts/inject-plan.sh --context=userprompt` | Emits full `task_plan.md` + last 20 lines of `progress.md`, wrapped in `===BEGIN/END PLAN DATA===` delimiters; blocks emission if the plan hash was attested and the file diverged |
| `PreToolUse` | `scripts/inject-plan.sh --context=pretool` | Emits the plan head (first 30 lines) only |
| `PostToolUse` | `scripts/post-tool-use.sh` | Reminds to update `progress.md`; self-filters to `edit`/`write` via the `TOOL_NAME` env var; skips if the edited file is `progress.md`/`task_plan.md` (loop guard) |
| `Stop` | `scripts/gate-stop.sh` → `scripts/check-complete.sh` | Reports phase-completion status; advisory only (always exit 0) |
| `PreCompact` | `scripts/inject-plan.sh --context=precompact` | Emits a compaction reminder (ensure planning files are current) |

Plan resolution order (in `resolve-plan-dir.sh`): `$PLAN_ID` env →
`.planning/.active_plan` → newest `.planning/*/` by mtime → legacy root
`task_plan.md`. No plan file found → script exits 0 silently.

Other scripts: `init-session.sh` (create plan files; with a name arg, an
isolated `.planning/YYYY-MM-DD-<slug>/` dir for parallel tasks),
`set-active-plan.sh` (switch the active plan pointer), `attest-plan.sh`
(optional SHA-256 attestation of `task_plan.md`), `check-complete.sh`
(verify all phases complete).

Templates: `templates/task_plan.md` (goal, current phase, phase checklist with
`pending → in_progress → complete` status, key questions, decisions table,
errors table), `templates/findings.md` (research storage),
`templates/progress.md` (session log with timestamped entries).

Dead content (features that do not exist in Respondami):

- "Pi Extension Hooks" section (modes `auto`/`parity`/`cache-safe`/`notify`,
  `/plan-status`, `/plan-attest`, `/plan-goal`, `/plan-loop` commands) —
  Respondami has no such extension or slash-command system.
- `scripts/session-catchup.py` and its references — reads Claude/Codex/
  OpenCode session record formats that Respondami does not produce.
- Security-boundary table rows referencing the removed commands.

## Validated decisions

| # | Decision | Choice |
| --- | --- | --- |
| 1 | Rework depth | Moderate — keep the battle-tested core prompt, fix the gaps, remove dead sections |
| 2 | Template reading | Hard, explicit step: `read` all three templates before creating planning files |
| 3 | Phase discipline | Explicit PHASE GATE checklist before starting the next phase |
| 4 | Hook matchers | Use the new frontmatter `matcher` field; keep script self-filtering as a second defense layer |
| 5 | Attestation | Keep `attest-plan.sh` as an optional manual step; drop slash-command references |
| 6 | Order | After the Respondami core design lands (its matchers/notes describe that behavior) |

## Section A: frontmatter matchers

Add `matcher` to the tool-event hook entries so the Respondami loader filters
before spawning (the scripts' internal `TOOL_NAME` checks stay as a second
defense layer against frontmatter/script drift):

- `PreToolUse` (inject-plan `--context=pretool`):
  `matcher: "Read|Write|Edit|Bash"` — Respondami's main tools.
- `PostToolUse` (post-tool-use reminder): `matcher: "Write|Edit"`.
- `PreCompact`: `matcher: "*"` — format fidelity; ignored by the loader.
- `UserPromptSubmit`/`Stop`: no matcher (no tool context).

`post-tool-use.sh` keeps its `case "${TOOL_NAME}" in edit|write)` check
unchanged.

## Section B: `SKILL.md` prompt changes

1. **Hard template-reading step** (closes the observed gap). In Quick Start,
   replace "Use [templates/task_plan.md](...) as reference" with:
   > Before creating any planning file, `read` `templates/task_plan.md`,
   > `templates/findings.md`, and `templates/progress.md` from this skill's
   > directory. Create the planning files following their exact structure.
   > Do not invent your own structure.
2. **Explicit PHASE GATE** (new section after "Update After Act"):
   > Before starting the next phase, all of these must be true:
   > 1. `task_plan.md`: current phase marked `complete`, next phase marked
   >    `in_progress`, `Current Phase` field updated.
   > 2. `progress.md`: session entry appended for the finished phase (actions
   >    taken, test results, files touched).
   > 3. `findings.md`: any discoveries from the phase recorded.
   > If you catch yourself starting phase N+1 work before the gate, stop and
   > complete it first.
3. **"Respondami notes" section** (new, near top): states what the hooks do
   now — plan injected each turn (do not re-read `task_plan.md` manually
   unless a gate requires it), progress reminder after every edit/write,
   completion status reported at turn end, matcher filters which tool calls
   trigger hooks. Prevents double-reading and tells the model the automation
   is live.
4. **Dead-section removal**: Pi Extension Hooks section, `session-catchup.py`
   and its references, `/plan-attest`/`/plan-status`/`/plan-goal`/
   `/plan-loop` command references, corresponding security-boundary table
   rows. `attest-plan.sh` stays, documented as an optional manual step
   (`sh scripts/attest-plan.sh`).
5. `scripts/session-catchup.py` is deleted from the skill (dead code; the
   "Restore Context" section keeps its manual steps: check for existing
   planning files, read them, update from `git diff`).

Kept unchanged: core pattern, file purposes, critical rules, 3-strike error
protocol, read/write decision matrix, 5-question reboot test, when-to-use
section, parallel-task workflow, `examples.md`, `reference.md`.

## Section C: files changed

```
agentskills/planning-with-files/
├── SKILL.md          # Sections A + B
├── scripts/
│   └── session-catchup.py   # deleted
└── (templates/, other scripts unchanged)
agentskills/README.md         # planning-with-files row notes the Respondami adaptation
```

Re-sync `agentskills/planning-with-files/` →
`~/.config/respondami/skills/planning-with-files/` after the change.

## Section D: verification (manual end-to-end checklist)

No test framework (it's a skill). Run in a scratch project after both
designs are implemented:

1. Fresh session, ask for a multi-step task → skill activates, the three
   templates are read (visible tool calls), planning files created with the
   template structure.
2. Mid-task: `task_plan.md` phase status and `progress.md` entries are
   current — the gate is being followed, not just end-of-task updates.
3. TUI shows hook lines (minimal mode): `✓ hook: UserPromptSubmit -
   planning-with-files:inject-plan.sh` per prompt, `✓ hook: PostToolUse -
   planning-with-files:post-tool-use.sh` after edits only (not after reads).
4. Quit and resume the session → the next turn's context contains the plan
   injection without re-activating the skill.
5. No plan file present (unrelated project) → hooks fire, emit nothing, no
   TUI noise beyond the minimal lines.

**Success criteria:** `progress.md` gets an entry after every phase and
`task_plan.md` status updates at each gate — verifiable by reading the files
mid-task; quit/resume requires no manual re-orientation.

## Out of scope (YAGNI)

- Porting `session-catchup.py` to the Respondami session format.
- New templates or new scripts.
- Changing the plan-file format or the `.planning/` parallel-plan layout.
- Hard stop-gating (advisory only).
- Any Respondami core changes (separate design).
