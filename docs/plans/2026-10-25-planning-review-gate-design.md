# Design: Review Gate extension for planning-with-files

## Context

Extends the `planning-with-files` skill with a review step: after implementation, staged changes are reviewed by the `review` skill; C/H/M findings trigger a fix phase and re-review; a clean report gates the commit. Designed per `writing-great-skills` principles.

Decisions locked during brainstorming:

- D1: `review` becomes model-invoked (planning must reach it)
- D2: fixed `Review` phase in the template; fix phases appended dynamically; Delivery = commit + handoff
- D3: cap at 3 fix cycles, then escalate (mirrors 3-Strike protocol)
- D4: stage everything (`git add -A`)
- D5: commit message via `caveman-commit`
- D6: non-git repo → skip review gate, note it, deliver without commit

## 1. The Review Gate (flow overview)

The extension adds a **Review Gate** to the planning lifecycle, using the word *gate* to stay in the skill's existing vocabulary (PHASE GATE). The flow, for code tasks in a git repo:

1. Last implementation phase complete → `git add -A`
2. Review phase `in_progress` → invoke the `review` skill in staged mode
3. Read the summary table of the report the review just wrote
4. **0 Critical/High/Medium** → Review phase `complete` → Delivery: commit via `caveman-commit`, deliver, task done
5. **≥1 C/H/M** → append a Fix phase *after* Review, one checkbox per C/H/M finding; work it; completion = all findings fixed and re-staged (`git add -A`)
6. Back to Review → re-invoke the review skill (staged mode; the report counter gives a fresh file)
7. After **3 fix cycles** with findings still remaining → escalate to the user (3-Strike rule)

Design choices baked in:

- The Review phase *owns the loop*; fix phases are discrete, appended phases, so the status machinery (`pending`/`in_progress`/`complete`, Stop-hook veto, `check-complete.sh`) works unchanged.
- **Low findings never block** — they stay in the report only.
- Detection is mechanical and in-context: the agent reads the summary table of the report it just produced. No new parsing script (YAGNI).
- The re-review is a *new* report (`-2`, `-3`, …), so the history of each round is preserved.
- Non-git repo: Review marked complete with a note, Delivery delivers without a commit.

## 2. Changes to the `review` skill

Two changes, both in `review/SKILL.md` frontmatter:

1. **Remove `disable-model-invocation: true`** — makes the skill model-invoked and reachable from `planning-with-files`. The writing-great-skills rule licenses exactly this: model-invocation is picked when "another skill must reach it."

2. **Rewrite the description** for model-facing use. Current description is human-facing ("Systematic multi-pass code review…"). New one, per the description rules (front-load the leading word, one trigger per branch, cut identity already in the body):

   > Systematic multi-pass code review for Rust, TypeScript, Java — whole project, single file, commit, or staged changes. Findings report in `docs/reviews/`. Use when the user asks to review code, or when the planning-with-files Review phase runs.

   The four scope branches (project / file / commit / staged) are the genuine trigger branches; the last clause is the reach clause for the planning skill.

No changes to the review skill's body, passes, report format, state file, or PreCompact hook — the staged mode already exists and is exactly what the gate needs. The cost of model-invocation (description in context every turn) is the price the writing-great-skills framework says to pay for cross-skill reach.

## 3. Template changes (`templates/task_plan.md`)

The 5-phase template becomes 6 phases (the template's own comment allows 3–7):

- Phases 1–4 unchanged (Requirements & Discovery, Planning & Structure, Implementation, Testing & Verification)
- **New Phase 5: Review**
- **Phase 6: Delivery** (was Phase 5, re-scoped)

New Phase 5 content, following the template's existing `WHAT/WHY` comment style:

```markdown
### Phase 5: Review
<!--
  WHAT: Run the review skill on the staged changes; loop fix/re-review until clean.
  WHY: Catches C/H/M findings before they land in a commit.
  Applies to code tasks in a git repo. Non-git: mark complete with a note.
-->
- [ ] Stage all changes (`git add -A`)
- [ ] Run the review skill on the staged changes
- [ ] If C/H/M findings: append a Fix phase, address them, re-review
- [ ] Complete only when the latest staged review shows 0 Critical/High/Medium
- **Status:** pending
```

Re-scoped Phase 6:

```markdown
### Phase 6: Delivery
<!--
  WHAT: Commit the reviewed, staged changes and hand off.
  WHY: The commit is the deliverable; the review gate guarantees its quality.
-->
- [ ] Commit staged changes (message via caveman-commit)
- [ ] Deliver to user
- [ ] Non-git repo: skip commit, note in progress.md
- **Status:** pending
```

The completion checkbox on Phase 5 is the checkable, exhaustive bound that resists premature completion: "0 C/H/M in the *latest* staged review" — the agent can tell done from not-done by reading the summary table. Fix phases are not in the template; they are appended at runtime with the finding list as checkboxes.

## 4. New section in `planning-with-files/SKILL.md`

A new top-level section, **"Review Gate"**, placed right after the PHASE GATE rule (co-location: the gate machinery sits beside the gate it extends). It is steps with a checkable completion criterion, not reference:

```markdown
## Review Gate

Applies to the Review phase of code tasks in a git repo. Non-git repo:
mark Review complete with a note in progress.md; Delivery skips the commit.

1. When the last implementation phase is complete, run `git add -A`
   and mark the Review phase `in_progress`.
2. Invoke the `review` skill on the staged changes.
3. Read the summary table of the report it wrote.
4. 0 Critical/High/Medium → mark Review `complete`, proceed to Delivery.
5. ≥1 C/H/M → append a Fix phase after Review: one checkbox per finding,
   each citing the finding id (C-1, H-2, M-3). Mark it `in_progress`.
   Completion: every finding fixed and changes re-staged (`git add -A`).
6. Fix phase complete → back to step 2 (a fresh report is written).
7. After 3 fix cycles with C/H/M findings remaining → stop the loop and
   escalate to the user: list the open findings and what was tried
   (3-Strike rule).
```

Supporting edits, kept minimal:

- The "File Purposes" and "Critical Rules" sections stay as-is; the gate is a phase-level concern, not a file-level one.
- One line added to the Delivery/commit context: commit message via `caveman-commit` (the skill is model-invoked; the Delivery phase fires it).
- No new scripts. `check-complete.sh` already counts dynamically appended phases; the Stop hook already vetoes stopping while the Review or a Fix phase is incomplete; the PreCompact hooks of both skills already keep the plan and the in-flight report alive across compaction.

The section deliberately does not restate any review mechanics (passes, severities, report format) — that stays single-sourced in the `review` skill.

## 5. Edge cases and validation

**Edge cases and their handling:**

| Case | Handling |
|------|----------|
| Non-git repo | Review marked complete with a note; Delivery delivers, no commit |
| Staged changeset has no supported language (e.g., only docs) | Review skill stops with a clear message, writes no report → Review phase marked complete with a note; Delivery proceeds to commit |
| Only Low findings | No Fix phase; Review complete; Low findings stay in the report |
| Fix cycle introduces new findings | Normal loop path; each round gets a fresh report (`-2`, `-3`, …) |
| 3 fix cycles exhausted, findings remain | Escalate: open findings + attempts listed; plan stays open (Review `in_progress`), user decides |
| Compaction mid-loop | Planning PreCompact re-emits the plan; review PreCompact re-emits the in-flight report; both mechanisms already exist |
| Unrelated in-flight work in the tree | `git add -A` stages it too; accepted trade-off (D4) — the user manages their own working tree |

**Validation plan** (mirrors the 8-run matrix used for the review skill):

1. **Clean path** — small code task with no C/H/M findings: Review completes in one pass, commit made with a caveman-commit message.
2. **Fix loop path** — task seeded with a known bug (e.g., swallowed error → High): verify Fix phase appended with the finding id, fix applied, re-review clean, commit made.
3. **Escalation path** — task where a finding is deliberately not fixable: verify escalation after 3 cycles, plan left open.
4. **Non-git path** — plan in a non-git directory: Review noted, delivery without commit.
5. **Regression** — existing plans (5-phase, no Review) still pass `check-complete.sh --strict`; the review skill's standalone 8-run matrix still passes with the new frontmatter.

No new scripts, no new state files, no hook changes — the extension is pure skill text: one frontmatter change in `review`, one new section in `planning-with-files/SKILL.md`, and the template update.
