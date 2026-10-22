# Design: `planning-with-files` — PreCompact: drop the no-op instruction, inject the plan body

- **Date:** 2026-10-22
- **Status:** Validated (all sections approved by user)
- **Location of work:** `agentskills/planning-with-files/`
- **Live skill dir:** `~/.config/respondami/skills/planning-with-files/` (re-synced after changes)
- **Source issue:** The PreCompact hook fires correctly before compaction, but the LLM
  has no chance to follow its instructions — compaction runs immediately afterwards.

## Purpose

`inject-plan.sh --context=precompact` currently emits only a reminder:

```
[planning-with-files] PreCompact: context compaction is about to occur.
Before compaction completes: ensure progress.md captures recent actions and task_plan.md status reflects current phase.
task_plan.md, findings.md, progress.md remain on disk and will be re-read after compaction.
```

Respondami captures PreCompact hook stdout and **appends it to the compaction
summary** (`event_loop.rs` `handle_compaction_result`). The LLM therefore sees
this text only *after* compaction, inside the summary. Consequences:

1. The instruction "ensure progress.md captures recent actions…" is a no-op: the
   LLM cannot act on it before compaction, and by the time it is visible the
   recent actions are already out of working context.
2. The plan body is never injected into the summary, so `task_plan.md` survives
   compaction only if the LLM's summary happens to preserve it.

## Validated decisions

| # | Decision | Choice |
| --- | --- | --- |
| 1 | Keep or remove the PreCompact hook | Keep — it is the only plan injection into the summary on the mid-turn path |
| 2 | What `precompact` mode emits | Full `task_plan.md` body in `===BEGIN/END PLAN DATA===` delimiters (same as `userprompt` mode) |
| 3 | The no-op instruction | Removed |
| 4 | The "files remain on disk" note | Kept, reworded as a factual line (not an instruction) |
| 5 | `Plan-SHA256 at compaction` line | Kept (attested plans only) |
| 6 | Attestation on tamper | Block plan injection with `[PLAN TAMPERED]` warning — consistent with `pretool`/`userprompt` |
| 7 | "Compaction prep" agent turn before compaction (alternative) | Rejected — extra LLM call, latency, new hook semantics; the deterministic injection already preserves the plan |

## Why the hook is still needed: two compaction paths

- **Pre-prompt compaction** (`respondami/src/turn.rs`): `UserPromptSubmit` fires
  first and injects the full plan into the model input, which is stored as the
  pending turn and launched after compaction. The PreCompact plan injection is
  redundant here (harmless duplicate).
- **Mid-turn compaction** (`respondami/src/agent_events.rs`, overflow /
  threshold): `UserPromptSubmit` does **not** fire again. The agent restarts
  with the retry message; the only plan content in context is the PreCompact
  output in the summary plus `PreToolUse` heads before tool calls. If the model
  replies with text only, the plan would be absent. The PreCompact plan body is
  the only thing that guarantees the plan is in context.

## Section A: `inject-plan.sh --context=precompact`

Replaces the reminder-only branch. New output (unattested plan):

```
[planning-with-files] PreCompact: context compaction is about to occur.
Plan files remain on disk and are the source of truth; re-read them if context is lost.
===BEGIN PLAN DATA===
<full task_plan.md, verbatim>
===END PLAN DATA===
```

- Attested plan: `Plan-SHA256 at compaction: <hash>` line after the note
  (existing behavior, retained).
- Tampered plan: `[planning-with-files] [PLAN TAMPERED — injection blocked]`
  with expected/actual hashes and the re-approve hint — same treatment as
  `pretool`/`userprompt` (the `TAMPERED` check already exists in the script;
  the precompact branch simply starts using it).
- No plan resolved → silent `exit 0` (unchanged).
- Full body (not the smart head): compaction is rare, so token cost is a
  non-issue; the purpose is verbatim preservation, and the model already sees
  the full plan every turn via `userprompt` mode, so the shape is familiar.

## Section B: docs

- `SKILL.md` "Respondami notes": add a PreCompact bullet — the full plan is
  injected into the compaction summary, so the plan survives compaction; this
  matters for mid-turn compaction, where no new `UserPromptSubmit` fires.
- `SKILL.md` Scripts section: `inject-plan.sh` entry — `--context=precompact`
  changes from "(compaction reminder)" to "(full plan body, appended to the
  compaction summary)".
- `README.md` hook table: `PreCompact` row changes from "Reminds to bring
  planning files current before compaction" to "Injects the full plan into the
  compaction summary so the plan survives compaction".

## Section C: files changed

```
agentskills/planning-with-files/
├── SKILL.md                    # docs: PreCompact note + script description
├── README.md                   # hook table row
└── scripts/
    ├── inject-plan.sh          # precompact: full plan body + tamper check
    └── test-hooks.sh           # flip + extend precompact tests
```

Re-sync `agentskills/planning-with-files/` →
`~/.config/respondami/skills/planning-with-files/` after the change.

## Section D: verification

`scripts/test-hooks.sh` updates:

1. Test 5d flips: `precompact` output now **contains** the plan body (e.g.
   `Phase 6` from the synthetic fixture) and the BEGIN/END delimiters.
2. New: `precompact` output does **not** contain the old instruction text
   ("ensure progress.md captures recent actions").
3. New: attested plan → `precompact` contains `Plan-SHA256 at compaction`;
   tampered plan → `precompact` contains `[PLAN TAMPERED]` and no plan body
   (fixture 6's "both modes" becomes "all injection modes").

Manual E2E checklist (real session, local LLM):

- Force a mid-turn compaction (small `keep_recent_tokens`) → the compaction
  summary in the session file contains the full plan between the delimiters.
- Post-compaction turn: model continues the correct phase without re-reading
  `task_plan.md`.

Delivery: run test script, re-sync live skill dir, commit (caveman-commit).

## Out of scope (YAGNI)

- Any Respondami core changes (hook capture/append mechanics stay as-is).
- The upstream `planning-with-files` repo (separate project; its
  `pre-compact.sh` targets other runtimes where PreCompact output reaches the
  model before compaction).
- A "compaction prep" agent turn that lets the model flush `progress.md` before
  compaction (rejected in decision 7).
- Injecting `findings.md`/`progress.md` into the summary (the plan is the
  coordination artifact; the others are re-readable on demand and already
  summarized by the LLM).
