---
name: arch-review
description: In-depth architecture review for any Rust codebase — modularization, separation of concerns, call hierarchy, memory, performance, inconsistencies. Outputs findings to docs/reviews/arch-YYYY-MM-DD.md.
disable-model-invocation: true
---

# Architecture Review

A systematic architecture review for any Rust codebase. Eight passes in dependency order, each producing structured observations. Output: a review report in `docs/reviews/arch-YYYY-MM-DD.md`.

## Pass Strategy

Run all eight passes sequentially. Each pass is exhaustive — every file in scope is examined. Write observations to `findings.md` after each pass (the 2-action rule). Re-read `findings.md` before the final pass to synthesize.

### Pass 1 — Inventory & File Map

Establish the terrain. Gather:

- **File inventory**: `find src crates -name '*.rs' | xargs wc -l | sort -n`
- **Line count distribution**: bucket files by size (<100, 100-299, 300-499, 500-699, 700-799, 800-999, 1000+)
- **Crate map**: workspace members, dependency graph (`cargo tree --depth 1`), internal crate boundaries
- **Module tree**: `cargo doc --no-deps --document-private-items` or manual `mod` tracing
- **Entry points**: `main.rs`, `lib.rs` roots, public API surface

**Deliverable**: File size table, module tree, crate organization table.

### Pass 2 — Architecture & Module Structure

Evaluate the structural foundations. For each crate and module:

- **Crate boundaries**: Are library crates properly separated from binary crates? Can they be used independently?
- **Module cohesion**: Does each module have a single, clear responsibility? Or does it accumulate unrelated functions?
- **Dependency direction**: Do dependencies flow in one direction (data → business logic → UI)? Or are there circular/cross-cutting imports?
- **Public API surface**: Is the `pub` surface minimal and intentional? Or are internal types exposed unnecessarily?
- **Abstraction quality**: Are traits used where polymorphism is needed? Is the abstraction leak-free?

**Grade each crate** (A / A- / B+ / B / B- / C) with one-sentence rationale.

### Pass 3 — Separation of Concerns

Find tangled responsibilities. Check for:

- **God objects**: Structs or modules that own too many unrelated fields/methods. Flag any struct with >15 public fields or any module file >500 production lines.
- **Cross-cutting concerns**: Logic that belongs in one layer but lives in another (e.g., I/O in business logic, rendering in data types, middleware in core loops).
- **Leaky boundaries**: Modules that import from layers they shouldn't (UI code importing persistence, handlers importing rendering types).
- **Facade bloat**: Facade structs (`App`, `Context`, `Manager`) that accumulate behavior instead of delegating to sub-structs.
- **Duplication across modules**: Same logic implemented differently in two places (render loops, error handling, scroll management).

For each issue: note the files involved, what's tangled, and where the boundary should be.

### Pass 4 — Call Hierarchy & Flow

Trace the critical paths. Identify and document:

- **Entry points → core flow**: Map the full call chain from user action to completion (e.g., input → handler → orchestrator → worker → events → render).
- **Event loops**: How many event loops exist? Are they consistent (same event source, same poll pattern)?
- **Channel/message boundaries**: Where does data cross async boundaries? Is the channel protocol well-defined?
- **Callback depth**: Are there deeply nested callbacks or continuations that obscure flow?
- **Duplication in parallel paths**: Do parallel code paths (main loop vs worker loop) duplicate rendering, event handling, or state management?

**Deliverable**: ASCII call-flow diagrams for each critical path, duplication table.

### Pass 5 — Large Files & Functions

Identify hotspots that need attention:

- **Files >500 production lines**: List each with production vs. test line split, and assessment (coherent / should split / tests should extract).
- **Functions >50 lines**: List each with purpose and assessment (complex but necessary / should decompose / should extract helper).
- **Deep nesting**: Functions with >4 levels of indentation (cognitive load indicator).
- **Parameter count**: Functions with >4 parameters (consider struct or builder).
- **Match arms**: Match expressions with >8 arms (consider enum grouping or trait dispatch).

**Deliverable**: Table of large files (file, total, production, tests, assessment) and large functions (function, location, lines, assessment).

### Pass 6 — Memory Usage Patterns

Find allocation pressure and unnecessary copies:

- **String cloning**: `.clone()` on `String`/`Vec` across function boundaries. Is the clone necessary or is a `&str`/`&[T]` sufficient?
- **Arc/Box overuse**: `Arc` where `&` or owned value would suffice. `Box` for small types that fit on stack.
- **Unnecessary heap allocations**: `String` for temporary buffers that could be `&str`, `Vec` for fixed-size data that could be arrays.
- **Per-frame allocations**: Render paths that allocate every frame (Strings, Vectors, HashMaps) instead of reusing pools.
- **Cache misses**: Data reloaded from disk on every use instead of cached (config, resources, file listings).
- **Dead dependencies**: Dependencies in `Cargo.toml` not used anywhere (`cargo tree --edges normal --depth 1` and cross-reference).
- **Collection choices**: `HashMap` when `Vec` + binary search would suffice for small datasets. `Vec` when capacity is unknown and grows unboundedly.

**Deliverable**: Table of memory issues (location, pattern, impact, fix).

### Pass 7 — Performance Characteristics

Identify bottlenecks and unnecessary work:

- **Render path**: What runs every frame? Is O(n) work done on every render when only O(1) changed?
- **Hot loops**: Tight loops with expensive operations (string formatting, regex, JSON parsing).
- **I/O patterns**: Synchronous I/O on async runtime? Unbuffered reads? Missing `sync_all`?
- **Redundant computation**: Values recomputed every frame that could be cached (heights, layouts, colors).
- **Inefficient data structures**: Linear search where hash lookup would be O(1). Full collection iteration where incremental update would suffice.
- **Serialization**: JSON serialization in hot paths. Consider `serde_json::to_writer` instead of `to_string` for large payloads.

**Deliverable**: Table of performance issues (location, issue, impact, fix).

### Pass 8 — Inconsistent Implementations

Find the same thing done differently:

- **Pattern inconsistency**: Same operation implemented differently in two modules (different error handling, different scroll logic, different event polling).
- **Naming inconsistency**: Same concept named differently across modules (`scroll_offset` vs `scroll_pos`, `is_done` vs `completed`).
- **API inconsistency**: Similar functions with different signatures (some take `&self`, some `&mut self`; some return `Result`, some `Option`).
- **Convention inconsistency**: Test organization (inline vs separate file), documentation style, comment conventions.
- **Abstraction inconsistency**: Some code paths use traits/abstractions, parallel paths use direct calls.

**Deliverable**: Table of inconsistencies (pattern, location A, location B, recommendation).

---

## Output Format

Write the review to `docs/reviews/arch-YYYY-MM-DD.md` with these sections:

### 1. Executive Summary

One paragraph. Overall grade (A / A- / B+ / B / B- / C). Top 3 strengths, top 3 issues.

### 2. Architecture Overview

- High-level structure (ASCII diagram of major components and data flow)
- Crate organization table (crate, lines, purpose, grade)
- Module tree (key modules and their responsibilities)

### 3. Separation of Concerns

For each major subsystem: grade, assessment, identified issues.
Table: subsystem, grade, notes.

### 4. Call Hierarchy / Call Flow

ASCII call-flow diagrams for each critical path.
Duplication table (what's duplicated, where, why).

### 5. Large Files and Functions

Table: file, total lines, production, tests, assessment.
Table: function, location, lines, assessment.

### 6. Memory Usage Patterns

Table: location, pattern, impact, fix.

### 7. Performance Characteristics

Table: location, issue, impact, fix.

### 8. Inconsistent Implementations

Table: pattern, location A, location B, recommendation.

### 9. Recommendations

Prioritized table:

| Priority | # | Recommendation | Impact | Effort |
|----------|---|---------------|--------|--------|
| High | H1 | ... | ... | ... |
| Medium | M1 | ... | ... | ... |
| Low | L1 | ... | ... | ... |

Priorities: **High** = clear bug or significant waste, **Medium** = maintainability or moderate improvement, **Low** = polish or future-proofing.
Impact: **Low** / **Medium** / **High**.
Effort: **Low** (<1 hour) / **Medium** (1-4 hours) / **High** (>4 hours).

### 10. Strengths

Numbered list of what the codebase does well. Be specific — reference actual patterns, not vague praise.

### Appendix

File size distribution histogram. Any supplementary data.

---

## Grade Definitions

| Grade | Criteria |
|-------|----------|
| **A** | Excellent architecture. Clear boundaries, no god objects, consistent patterns, no significant issues |
| **A-** | Strong architecture with minor issues (1-2 medium findings) |
| **B+** | Good architecture, some large files or minor inconsistencies, clear improvement path |
| **B** | Functional but with notable issues: tangled modules, duplicated logic, performance concerns |
| **B-** | Significant architectural debt: god objects, leaky abstractions, inconsistent patterns |
| **C** | Needs restructuring: circular dependencies, no clear boundaries, major duplication |

## File Reading Strategy

Read files in dependency order — foundations first:

1. **Root files**: `Cargo.toml`, `Cargo.lock` (workspace), `src/main.rs`, `src/lib.rs`
2. **Core types**: Config, enums, traits, public API types
3. **Infrastructure**: Provider layer, persistence, error types
4. **Business logic**: Core loops, handlers, commands, middleware
5. **UI/rendering**: Layout, rendering, state management
6. **Supporting**: Logging, utilities, tests

Read each file in full. For large files (>500 lines), read in sections if needed but understand the full structure.

## Scope

**In scope**: Architecture, modularization, separation of concerns, call hierarchy, memory usage, performance, consistency, large files/functions.
**Out of scope**: Style/formatting (clippy handles this), test coverage metrics, bug hunting (use code-health-check for that), documentation completeness, security audit.
