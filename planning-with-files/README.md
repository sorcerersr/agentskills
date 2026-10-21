# Planning with Files

> **Work like Manus** - Use persistent markdown files as your "working memory on disk."

A skill for the Respondami agent. It enforces Manus-style file-based planning:
`task_plan.md`, `findings.md`, and `progress.md` are created up front in the
project directory and updated after every phase, so a session can be quit and
resumed with minimal friction.

Adapted from [planning-with-files](https://github.com/OthmanAdi/planning-with-files/)
for Respondami: lifecycle hooks are declared in the skill's frontmatter
(matcher-filtered), and the prompt has a hard template-reading step and an
explicit phase gate.

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

## Lifecycle hooks

The frontmatter declares five hooks that keep the plan in the model's
attention window:

| Event          | Behavior                                                                     |
| -------------- | ---------------------------------------------------------------------------- |
| `UserPromptSubmit` | Injects full `task_plan.md` + recent `progress.md`, wrapped in `===BEGIN/END PLAN DATA===` delimiters |
| `PreToolUse`   | Injects the plan head (first 30 lines) before `Read`/`Write`/`Edit`/`Bash`  |
| `PostToolUse`  | Reminds to update `progress.md` after `Write`/`Edit` (skips plan-file edits) |
| `Stop`         | Reports phase-completion status (advisory only)                              |
| `PreCompact`   | Reminds to bring planning files current before compaction                    |

`matcher` fields filter which tool calls fire the hooks; the scripts also
self-filter on `TOOL_NAME` as a second defense layer. If no plan file exists,
all hooks emit nothing and exit 0.

Attestation is optional: `sh scripts/attest-plan.sh` locks `task_plan.md` with
a SHA-256 hash. If the file later diverges, injection is blocked with:

```text
[planning-with-files] [PLAN TAMPERED - injection blocked]
```

## Scripts

- `init-session.sh` — create planning files; with a name argument, an isolated plan under `.planning/YYYY-MM-DD-<slug>/` for parallel tasks
- `set-active-plan.sh` — switch the active plan pointer
- `resolve-plan-dir.sh` — resolve the active plan directory (used by hooks)
- `check-complete.sh` — verify all phases are complete
- `attest-plan.sh` — optional SHA-256 attestation of `task_plan.md` (`--show`, `--clear`)

## File structure

The workflow centers on three files in your project:

```text
your-project/
├── task_plan.md
├── findings.md
└── progress.md
```
