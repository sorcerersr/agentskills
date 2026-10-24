---
name: code-health-check
description: Systematic three-pass code review for any Rust project — correctness, quality, and dependency audit. Outputs findings to docs/reviews/YYYY-MM-DD-code-review.md.
disable-model-invocation: true
---

# Code Health Check

A systematic code review for any Rust project. Three passes in dependency order, focused on correctness and quality. Output: a findings report in `docs/reviews/YYYY-MM-DD-code-review.md`.

## Pass 0 — Project Understanding

Before any review, establish context. Perform 3-5 quick actions:

1. Read `Cargo.toml` (workspace or single-crate) to understand dependencies, features, crate structure.
2. Run `find src crates -name '*.rs' | head -40` to see the module layout.
3. Read `README.md` if present, to understand purpose and conventions.
4. Run `git log --oneline -10` if in a git repo, to see recent work and context.

This produces a mental model of what the project does and what patterns may be intentional. Do not write this to the report — it is working context carried into subsequent passes.

## Pass Strategy

Run all three passes sequentially. Each pass is exhaustive — every file in its scope is read and evaluated against every rule.

### File Discovery & Review Order

Before Pass 1, discover the project structure:

1. Run `find src crates -name '*.rs' | xargs wc -l | sort -n` to inventory all Rust files.
2. Examine `mod.rs` files and `use` statements to understand module dependencies.
3. Group files into layers:
   - **Core types & config** — enums, traits, config structs, public API types
   - **Infrastructure** — I/O, networking, persistence, provider abstractions
   - **Business logic** — core loops, handlers, commands, orchestration
   - **UI / presentation** — rendering, layout, state management, widgets
   - **Utilities & tests** — helpers, test files, benchmarks
4. When directory structure clearly indicates layers (e.g., `src/core/`, `src/api/`), follow that. Otherwise, use the generic layered grouping above.
5. Review in dependency order: core → infrastructure → business logic → presentation → utilities.

Read each file in full; trace key functions through call sites; verify cross-module contracts.

### Pass 1 — Correctness (Critical/High)

Find bugs that break things. Check every file for:

- **Logic errors**: off-by-one, incorrect conditionals, wrong defaults, boundary conditions
- **Concurrency**: channel misuse, race conditions, TOCTOU, unsafe code, fire-and-forget tasks
- **Error handling**: swallowed errors (`ok()`, `unwrap_or_default()`), `unwrap()` in production paths, missing propagation, silent `continue`
- **Data integrity**: state corruption, BOM/encoding issues, path traversal, truncation
- **Edge cases**: empty inputs, zero-length sequences, nil states, missing finalizers

### Pass 2 — Code Quality (Medium/Low)

Find issues that degrade the codebase. Check every file for:

- **Naming**: misleading names, inconsistent conventions, semantically inaccurate function/parameter names
- **Duplication**: repeated patterns across modules, duplicate type definitions, dead code
- **Complexity**: functions doing too much, deep nesting, unclear control flow, fragile coupling
- **Architecture**: violations of established patterns, misplaced responsibilities, API misuse
- **DRY**: copy-paste code that should be abstracted

### Pass 3 — Dependency Audit

Audit `Cargo.toml` and the dependency tree. Check for:

- **Unused dependencies**: Run `cargo tree --edges normal --depth 1` and cross-reference each dependency against `grep -r` in `src/`. Flag deps with no imports.
- **Dev-dependency leakage**: Dev-dependencies imported in production code (outside `#[cfg(test)]`).
- **Duplicate functionality**: Multiple crates providing the same capability (e.g., two JSON serializers, two async runtime crates).
- **Outdated major versions**: Dependencies on old major versions with known breaking fixes or security patches in newer releases.
- **Unused features**: Features enabled in `Cargo.toml` that are not actually used by the code.
- **Configuration issues**: Typos in crate names, duplicate entries, conflicting version requirements across workspace members.

## Severity Definitions

| Level | Criteria |
|-------|----------|
| **Critical** | Data loss, silent corruption, security vulnerability, crash in normal usage |
| **High** | Incorrect behavior under common conditions, error swallowing, resource leaks, latent panics in production paths |
| **Medium** | Incorrect behavior under rare conditions, quality issues that could cause bugs, misleading APIs, documentation staleness |
| **Low** | Code smell, maintainability concern, inconsistent convention, dead code, minor inefficiency |

## Finding Format

Each finding follows this exact structure:

```markdown
### [SEV-N] Short title
- **Location**: `src/path/file.rs:line` or `src/path/file.rs` — function name (lines ~X-Y)
- **Issue**: What's wrong, described concisely
- **Why it matters**: Impact — what breaks, when, and how
- **Suggested fix**: Concrete code change or refactoring approach
```

For **Critical** and **High** findings, append a verification line:

```markdown
- **Verified**: ✓ Agent traced call path — condition is reachable via [brief path description]
```

Prefix: `C-` (Critical), `H-` (High), `M-` (Medium), `L-` (Low). Number sequentially within each severity.

## Scope

**In scope**: Correctness bugs, code quality issues, dependency audit.
**Out of scope**: Performance optimization, style/formatting (clippy handles this), documentation completeness, test coverage, security audit.

## Deliverable

Write the findings report to `docs/reviews/YYYY-MM-DD-code-review.md` with:

1. Header: scope (file count, LOC, crate count), focus, methodology
2. Summary table: severity counts
3. Findings grouped by severity (Critical → Low), each in the finding format above
4. Dependency audit summary table (dep name, status, notes)
