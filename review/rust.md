# Rust

Language file for the review skill. Load when `.rs` files are in scope.

## Pass 0 — Project Understanding (Rust)

1. Read `Cargo.toml` (workspace or single-crate) to understand dependencies, features, and crate structure.
2. Run `find src crates -name '*.rs' | xargs wc -l | sort -n` to inventory all Rust files.
3. Examine `mod.rs` files and `use` statements to understand module dependencies.
4. Group files into layers:
   - **Core types & config** — enums, traits, config structs, public API types
   - **Infrastructure** — I/O, networking, persistence, provider abstractions
   - **Business logic** — core loops, handlers, commands, orchestration
   - **UI / presentation** — rendering, layout, state management, widgets
   - **Utilities & tests** — helpers, test files, benchmarks
5. When directory structure clearly indicates layers (e.g., `src/core/`, `src/api/`), follow that. Otherwise, use the generic layered grouping above.
6. Review in dependency order: core → infrastructure → business logic → presentation → utilities.

## Pass 1 — Language Checks

- `unwrap()` / `expect()` in production paths
- Swallowed errors via `ok()` / `unwrap_or_default()`
- Channel misuse, race conditions, fire-and-forget tasks
- `unsafe` blocks without a soundness argument

## Pass 2 — Language Checks

- Glob re-exports that obscure where a type or function comes from
- Duplicate type definitions across crates
- Public API surface wider than necessary (leaking internal types)

## Pass 3 — Dependency Audit (Rust)

Audit `Cargo.toml` and the dependency tree. Check for:

- **Unused dependencies**: Run `cargo tree --edges normal --depth 1` and cross-reference each dependency against `grep -r` in `src/`. Flag deps with no imports. If `cargo tree` fails to resolve the manifest, fall back to cross-referencing the manifest directly and report the resolution failure as a configuration issue.
- **Dev-dependency leakage**: Dev-dependencies imported in production code (outside `#[cfg(test)]`).
- **Duplicate functionality**: Multiple crates providing the same capability (e.g., two JSON serializers, two async runtime crates).
- **Outdated major versions**: Dependencies on old major versions with known breaking fixes or security patches in newer releases.
- **Unused features**: Features enabled in `Cargo.toml` that are not actually used by the code.
- **Configuration issues**: Typos in crate names, duplicate entries, conflicting version requirements across workspace members.

In changeset mode, audit only the changed manifest entries.

## Pass 4 — Guideline Compliance (Rust)

- **Guidelines skill**: activate `rust-guidelines`.
- **Tooling to check first**: clippy (`clippy.toml`, `[lints]` in `Cargo.toml`), rustfmt.
- **Review notes**:
  - M-CANONICAL-DOCS documentation format: summary sentence under 15 words, then extended docs, with Examples / Errors / Panics / Safety sections as applicable.
  - `unsafe` blocks must carry a Safety section documenting the invariants.
  - Library crates: apply the `09`-`12` library guideline files when the in-scope code is a library crate.
