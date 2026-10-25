---
name: review
description: Systematic multi-pass code review for Rust, TypeScript, Java — whole project, single file, commit, or staged changes. Findings report in docs/reviews/. Use when the user asks to review code, or when the planning-with-files Review phase runs.
hooks:
  PreCompact:
    - hooks:
        - type: command
          command: sh ${SKILL_DIR}/scripts/precompact-emit.sh docs/reviews/.active_report
---

# Review

A systematic five-pass code review for Rust, TypeScript, and Java. Review scope: whole project, single file, or changeset. Output: a findings report in `docs/reviews/YYYY-MM-DD-<suffix>-review.md`.

## Scope Mode

Resolve the scope mode from the user's request:

| Mode | Trigger | In-scope files |
|------|---------|----------------|
| Project | `review` / "review the project" | every file with a supported extension |
| File | "review `src/foo.rs`" | that one file |
| Commit | "review commit `<sha>`" / "last commit" | `git show --name-only --format= <sha>` |
| Staged | "review staged changes" / "files to be committed" | `git diff --name-only --cached` |

- Ambiguous request: ask one clarifying question.
- Changeset request in a non-git repo: stop with a clear message.
- Filter in-scope files to supported extensions. If zero remain, stop with a clear message and write no report.

## Language Detection

By extension: `.rs` → Rust; `.ts`, `.tsx`, `.mts`, `.cts` → TypeScript; `.java` → Java.

For each detected language, load its language file from this skill's directory: `rust.md`, `typescript.md`, `java.md`. Load only the language files for languages present in the in-scope files; a mixed-language review loads several.

## Pass Matrix

| Pass | Project | File | Changeset |
|------|---------|------|-----------|
| 0 — Project understanding | yes | yes (light) | yes |
| 1 — Correctness | all files | the file | in-scope files |
| 2 — Quality | all files | the file | in-scope files |
| 3 — Dependency audit | yes | no | only if a manifest is in the changeset |
| 4 — Guideline compliance | all files | the file | in-scope files |

Run the passes in order. Each pass is exhaustive — every in-scope file is read in full and evaluated against every rule of the pass. Read each file in full; trace key functions through call sites; verify cross-module contracts. As each finding is generated, append it to the report immediately, in the finding format, under the appropriate severity group.

Findings are reported only for in-scope files; call-path tracing for the `Verified` line may cross into out-of-scope code.

## Pass 0 — Project Understanding

Before any review, establish context. Perform 3-5 quick actions:

1. Read the project's manifest(s) and build files (concrete artifacts per language file).
2. Inventory the module layout (discovery command per language file).
3. Read `README.md` if present, to understand purpose and conventions.
4. Run `git log --oneline -10` if in a git repo, to see recent work and context.
5. In file/changeset mode, narrow the inventory to the modules the in-scope files touch.

This produces a mental model of what the project does and what patterns may be intentional. Do not write this to the report — it is working context carried into subsequent passes.

After Pass 0, create the report with the header (see Report) and write its relative path to `docs/reviews/.active_report`. Fill in the exact scope numbers (file count, LOC) from file discovery.

## Pass 1 — Correctness (Critical/High)

Find bugs that break things. Check every in-scope file for:

- **Logic errors**: off-by-one, incorrect conditionals, wrong defaults, boundary conditions
- **Concurrency**: race conditions, TOCTOU, fire-and-forget tasks, synchronization misuse
- **Error handling**: swallowed errors, missing propagation, silent `continue`
- **Data integrity**: state corruption, encoding issues, path traversal, truncation
- **Edge cases**: empty inputs, zero-length sequences, nil states, missing finalizers

Plus the language checks from the language file.

## Pass 2 — Code Quality (Medium/Low)

Find issues that degrade the codebase. Check every in-scope file for:

- **Naming**: misleading names, inconsistent conventions
- **Duplication**: repeated patterns across modules, dead code
- **Complexity**: functions doing too much, deep nesting, fragile coupling
- **Architecture**: violations of established patterns, misplaced responsibilities
- **DRY**: copy-paste code that should be abstracted

Plus the language checks from the language file. Keep this pass at the "quality issue that could cause bugs" altitude — detailed naming and style rules are Pass 4's job.

## Pass 3 — Dependency Audit

Per the language file. In changeset mode, audit only the changed manifest entries.

## Pass 4 — Guideline Compliance

For each detected language:

1. **Activate** the language's guidelines skill (named in the language file).
2. **Topic scan**: note which guideline topics are present in the in-scope code. Load the "ALL tasks" files plus every file whose topic is present.
   *Completion criterion: every topic present in the in-scope code has a loaded file or a noted reason it doesn't apply.*
3. **Rule inventory**: extract the normative rules (`must`/`must not`/`should`/`should not`) from each loaded file.
4. **Evaluate every in-scope file against every rule** — same exhaustive discipline as Passes 1-2.
5. **Tooling precedence**: check the project's tooling config first (configs named in the language file). Rules the tooling enforces are out of scope.
6. **Consistency policy**: if the codebase consistently deviates from a rule (an established local convention), report it once as a Low "project convention deviates from guide" finding instead of one finding per occurrence.
7. **Non-normative examples**: optional formatting choices shown in guide examples are never enforced as rules.
8. **Findings**: standard format plus a `Guideline:` citation; severity per the Pass 4 mapping below.
9. Record the loaded guideline files in the compliance table.

## Severity Definitions

| Level | Criteria |
|-------|----------|
| **Critical** | Data loss, silent corruption, security vulnerability, crash in normal usage |
| **High** | Incorrect behavior under common conditions, error swallowing, resource leaks, latent panics in production paths |
| **Medium** | Incorrect behavior under rare conditions, quality issues that could cause bugs, misleading APIs, documentation staleness |
| **Low** | Code smell, maintainability concern, inconsistent convention, dead code, minor inefficiency |

Pass 4 mapping: `must`/`must not` violation → Medium; `should`/`should not` violation → Low; `must` violation that can cause incorrect behavior → High. Guideline violations never reach Critical.

## Finding Format

Each finding follows this exact structure:

```markdown
### [SEV-N] Short title
- **Location**: `path/file.ext:line` or `path/file.ext` — function name (lines ~X-Y)
- **Issue**: What's wrong, described concisely
- **Why it matters**: Impact — what breaks, when, and how
- **Suggested fix**: Concrete code change or refactoring approach
```

Pass 4 findings append one line:

```markdown
- **Guideline**: <lang> <guideline file> §<rule>
```

For **Critical** and **High** findings, append a verification line:

```markdown
- **Verified**: ✓ Agent traced call path — condition is reachable via [brief path description]
```

Prefix: `C-` (Critical), `H-` (High), `M-` (Medium), `L-` (Low). Number sequentially within each severity.

## Report

`docs/reviews/YYYY-MM-DD-<suffix>-review.md`, where the suffix is:

- Project: `code` (e.g., `2026-10-25-code-review.md`)
- File: the file name (e.g., `2026-10-25-parser.rs-review.md`)
- Commit: the short SHA (e.g., `2026-10-25-a1b2c3d-review.md`)
- Staged: `staged` (e.g., `2026-10-25-staged-review.md`)

If a report with the same name already exists that day, append a counter: `-2`, `-3`, …

The report is built incrementally: the header is written at creation (after Pass 0), findings are appended as they are generated, and the report is finalized on completion. The final report contains:

1. Header: scope mode, scope target (file path / commit SHA / "staged"), languages detected, file count + LOC in scope, focus, methodology
2. Findings: one list, grouped by severity (Critical → Low), all passes mixed
3. Compliance table (per language): guideline files loaded, must-violation count, should-violation count
4. Dependency audit table: dep name, status, notes — only when Pass 3 ran
5. Summary table: severity counts

On completion, append the summary table, the compliance table, and (if Pass 3 ran) the dependency audit table, then clear `docs/reviews/.active_report`.

## Scope

**In scope**: Correctness bugs, code quality issues, dependency audit, guideline compliance.
**Out of scope**: Performance optimization, tooling-enforced formatting, documentation completeness beyond guideline rules, test coverage, security audit.

## Respondami notes

- The `PreCompact` hook re-emits the in-progress report (marker-wrapped) into the compaction summary, so a long review that triggers compaction resumes with the full findings context instead of re-reviewing covered files.
- `docs/reviews/.active_report` pins the active report's relative path; the hook no-ops when the state file is missing (e.g., after completion) or when the path doesn't resolve.
