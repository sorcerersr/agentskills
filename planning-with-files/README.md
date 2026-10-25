# Planning with Files

> **Work like Manus** - Use persistent markdown files as your "working memory on disk."

A skill for the Respondami agent. It enforces Manus-style file-based planning:
`task_plan.md`, `findings.md`, and `progress.md` are created up front under
`.planning/<date>-<slug>/` in the project and updated after every phase, so a
session can be quit and resumed with minimal friction.

Adapted from [planning-with-files](https://github.com/OthmanAdi/planning-with-files/)
for Respondami: lifecycle hooks are declared in the skill's frontmatter
(matcher-filtered), and the prompt has an explicit phase gate. Planning files
are always created by `init-session.sh` under `.planning/` — never in the
project root.

## Installation

Copy the skill directory into the Respondami skills folder:

```bash
cp -a planning-with-files ~/.config/respondami/skills/
```

## Usage

Ask for the skill on any multi-step task:

```text
Use the planning-with-files skill to help me with this task.
```

The skill starts a plan with `scripts/init-session.sh "Task Name"`, which
creates `.planning/YYYY-MM-DD-<slug>/` containing the three planning files and
pins `.planning/.active_plan` so the hooks find it. Every plan is isolated in
its own directory, so multiple tasks in the same repo coexist; switch with
`set-active-plan.sh` or pin a terminal with `export PLAN_ID=<id>`.

## Lifecycle hooks

The frontmatter declares three hooks that keep the plan in the model's
attention window:

| Event          | Behavior                                                                     |
| -------------- | ---------------------------------------------------------------------------- |
| `PreToolUse`   | 2-Action Rule enforcement: blocks (exit 2) after 4 reads or 2 writes of non-planning files until findings are persisted to `findings.md` |
| `PreCompact`   | Injects the full plan into the compaction summary so the plan survives compaction |
| `Stop`         | Completion gate: vetoes the stop (exit 2) while the active plan is incomplete |

`matcher` fields filter which tool calls fire the hooks; the scripts also
self-filter on `TOOL_NAME` as a second defense layer. If no plan file exists,
all hooks emit nothing and exit 0.

Attestation is optional: `sh scripts/attest-plan.sh` locks `task_plan.md` with
a SHA-256 hash. If the file later diverges, injection is blocked with:

```text
[planning-with-files] [PLAN TAMPERED - injection blocked]
```

## Scripts

- `init-session.sh` — create planning files under `.planning/YYYY-MM-DD-<slug>/`; without a name, an `untitled-<uuid>` plan. Never writes to the project root
- `set-active-plan.sh` — switch the active plan pointer
- `resolve-plan-dir.sh` — resolve the active plan directory (used by hooks)
- `check-complete.sh` — verify all phases are complete
- `attest-plan.sh` — optional SHA-256 attestation of `task_plan.md` (`--show`, `--clear`)

## File structure

The workflow centers on three files in the active plan directory:

```text
your-project/
└── .planning/
    ├── .active_plan
    └── 2026-01-10-my-task/
        ├── task_plan.md
        ├── findings.md
        └── progress.md
```

Legacy projects may have the three files in the project root instead; the
hooks still resolve and support that layout, but new plans always go under
`.planning/`.
