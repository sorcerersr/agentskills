# Design: `planning-with-files` — local-LLM reliability fixes (hook log + smart head)

- **Date:** 2026-10-22
- **Status:** Validated (all sections approved by user)
- **Location of work:** `agentskills/planning-with-files/`
- **Live skill dir:** `~/.config/respondami/skills/planning-with-files/` (re-synced after changes)
- **Source issues:** `issues.md` (two issues observed with local LLM `coder_27b` + Respondami, the primary use case)

## Purpose

Two observed failures of the skill with local LLMs:

1. **Batched progress updates.** The PostToolUse reminder fires correctly, but the model
   reasons around it: *"I'll update progress.md at the end of this batch of changes
   (the hook is asking for an update right now, but I'm in the middle of a multi-file
   change, so I'll log it after the refactoring is done and the build passes)."*
   The purpose of fine-grained progress updates is that no information is lost when a
   batch is interrupted by compaction or a crash — the advisory reminder cannot
   guarantee that.
2. **Truncated pretool plan injection.** `inject-plan.sh --context=pretool` uses a
   fixed `head -30`. Root cause confirmed by reproduction: `head -30` on the 83-line
   Panzaaa plan produces byte-identical output to the observed hook output (ends at
   Phase 2's `Status: complete`). The current phase (6) is never in the injection.
   Not a display issue: config has `hook_display: "full"`, so the TUI shows exactly
   what the script emits. The truncated head is also the *most frequent* injection
   (every Read/Write/Edit/Bash), so it dominates the local model's recent context,
   while the full plan arrives only once per turn via `UserPromptSubmit`.

The two issues interact: repeatedly seeing a stale head blurs "where am I" and
encourages plowing through the batch.

## Validated decisions

| # | Decision | Choice |
| --- | --- | --- |
| 1 | Issue 1 mechanism | Hook writes a mechanical log line to `progress.md` (durability floor independent of the model); reminder text updated to frame the model's task as "add a description" |
| 2 | Log location | Dedicated `## Hook Log` section at the bottom of `progress.md` (not a separate file); `progress.md` becomes append-only by rule |
| 3 | Issue 2 mechanism | Content-aware "smart head": goal + one-line status rollup + full current-phase section; `head -30` only as parse-failure fallback |
| 4 | Current-phase selection | Trust `Current Phase` field, cross-checked against phase statuses; on mismatch prefer first `in_progress` (else first `pending`) and emit a one-line warning |
| 5 | Verification | New `scripts/test-hooks.sh` with synthetic fixtures (no private project content) + manual E2E checklist for live local-LLM behavior |

## Section A: mechanical hook log (Issue 1)

`scripts/post-tool-use.sh` (PostToolUse, matcher `Write|Edit`) stops being a pure
reminder:

1. Resolve the active plan (unchanged). No plan → exit 0 silently.
2. Parse `TOOL_INPUT` JSON for the edited path (existing logic). Basename
   `progress.md` or `task_plan.md` → exit 0 silently (existing loop guard).
3. **New:** append a mechanical line to `progress.md`:
   - Format: `- [HH:MM:SS] <tool>: <path> (<N> lines)`
     (timestamp via `date +%H:%M:%S`; path relative to CWD when possible;
     line count from `wc -l` after the edit, omitted if the file is gone).
   - `progress.md` already contains a `## Hook Log` heading → append the line at
     end of file.
   - No heading → append `\n## Hook Log\n` then the line.
   - The section is conventionally last; the hook never reorders content.
4. Reminder, reworded:
   > `[planning-with-files] A mechanical entry for this change was just appended to the ## Hook Log in progress.md. Now add your descriptive entry (what and why) to the session log. If a phase is complete, also update task_plan.md status.`

Why this breaks the failure mode: the mechanical record no longer depends on the
model. A compaction mid-batch loses the model's intent, not the fact that
`src/lib.rs` was edited at 14:03. The model's descriptive entries add the "why";
the reminder now frames the task as small and immediate ("add a description")
instead of deferrable ("write the log entry").

Safety: the hook's own append is not a model tool call, so it cannot retrigger
PostToolUse (no loop). `set -u` + `exit 0` discipline unchanged; any parse failure
degrades to reminder-only, never blocks the tool call.

Docs:
- `SKILL.md`: append-only rule for `progress.md` ("never rewrite wholesale; the
  `## Hook Log` is hook-maintained and stays last"), "Respondami notes" line,
  updated `post-tool-use.sh` description in the Scripts section, `progress.md`
  row in the File Purposes table.
- `templates/progress.md`: new `## Hook Log` section at the bottom with an
  explanatory comment (hook-maintained, do not edit by hand).

## Section B: smart head (Issue 2)

`scripts/inject-plan.sh --context=pretool` replaces `head -30` with:

```
===BEGIN PLAN DATA===
## Goal
<goal text, verbatim>

## Status
Phase 1: complete | Phase 2: complete | Phase 3: complete | Phase 4: complete |
Phase 5: complete | Phase 6: in_progress | Phase 7: pending

## Current Phase 6: <title>
<full section: checklist lines + Status line>
===END PLAN DATA===
```

Extraction (awk over `task_plan.md`):

- **Goal:** lines between `## Goal` and the next `## ` heading.
- **Phase statuses:** for each `### Phase N: Title` heading, the `**Status:** X`
  line in its section.
- **Current phase selection:**
  1. Read the `## Current Phase` field (e.g. `Phase 6`).
  2. Field's phase status is `in_progress` → use it.
  3. Else any phase is `in_progress` → use the first one; emit
     `[planning-with-files] WARNING: Current Phase field says 6, but Phase 5 is in_progress — using 5. Update the field.`
  4. Else field's phase is `pending` → use the first `pending` phase (warn if it
     differs from the field).
  5. Field missing/invalid (e.g. `Done`) → first `in_progress`, else first
     `pending`, else no current section.
  6. All phases complete → status rollup only, no current section.
- **Fallback:** no parseable `### Phase` headings at all → today's `head -30`.

Unchanged: `userprompt` mode (full plan + progress tail), `precompact` mode,
attestation/tamper handling (tampered plan still blocks injection in both modes),
plan resolution order, `===BEGIN/END PLAN DATA===` delimiters and data-only framing.

Size: ~15–35 lines regardless of plan length. The model's most-frequent injection
always contains exactly the work it is doing.

## Section C: files changed

```
agentskills/planning-with-files/
├── SKILL.md                    # docs: hook log, append-only rule, smart head
├── templates/
│   └── progress.md             # new ## Hook Log section
├── scripts/
│   ├── inject-plan.sh          # smart head for pretool mode
│   ├── post-tool-use.sh        # mechanical hook log + reworded reminder
│   └── test-hooks.sh           # NEW: fixture tests (synthetic plans only)
agentskills/README.md           # one-line note
```

Re-sync `agentskills/planning-with-files/` →
`~/.config/respondami/skills/planning-with-files/` after the change.

## Section D: verification

`scripts/test-hooks.sh` — self-contained, runs in a `mktemp -d` scratch dir, no
network, exits non-zero on any failure, prints a PASS/FAIL summary. All fixtures
are synthetic (fictional "Acme CLI — report export" project; **no Panzaaa or other
private project content** — agentskills is public), structured like
`templates/task_plan.md` and shaped like the 7-phase plan that exposed the bug.

Smart-head fixtures:

1. 7-phase plan, field `Phase 6`, Phase 6 `in_progress` → pretool output contains
   goal, full Phase 6 section, status rollup; does **not** contain Phase 2's
   checklist details (the old bug).
2. Stale field: field says 6, Phase 5 `in_progress` → output uses Phase 5 + warning.
3. Field `Done`, all complete → rollup only, no current section.
4. Plan with no `### Phase` headings → `head -30` fallback.
5. `userprompt` mode → full plan; `precompact` → reminder only.
6. Attestation: attested plan → injects; modified plan → `[PLAN TAMPERED]` block
   (both modes).

Hook-log fixtures:

7. `TOOL_NAME=write` + `TOOL_INPUT` JSON → one line appended under `## Hook Log`
   with correct format (timestamp, tool, path, line count); second call appends a
   second line.
8. `TOOL_NAME=edit` on `progress.md`/`task_plan.md` → no append, no reminder
   (loop guard).
9. No plan file → total silence.
10. `progress.md` without the section → hook creates `## Hook Log` then appends.

Manual E2E checklist (run in a real local-LLM session):

- Fresh multi-step task → `## Hook Log` line appears after each edit; model adds
  descriptive entries.
- Pretool injection in the TUI shows the current phase, not the oldest phases.
- Kill/compact mid-batch → resume; 5-Question Reboot Test answerable from the
  planning files alone.

Delivery: run test script, re-sync live skill dir, commit (caveman-commit).

## Out of scope (YAGNI)

- Changing the PreToolUse matcher (`Read|Write|Edit|Bash`) — the smart head is
  compact and stable; repetition is the feature for local LLMs. Revisit only if
  context bloat is observed.
- Logging `Bash` commands in the hook log (noisy; the model's descriptive entries
  cover test results).
- Deduplication of hook-log lines against model entries (duplication is cheap;
  the mechanical line is the floor).
- Hard-blocking enforcement of progress updates (Respondami hooks are advisory).
- Any Respondami core changes.
