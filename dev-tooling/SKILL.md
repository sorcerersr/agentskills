---
name: dev-tooling
description: >
  Discover which development tools are actually available in the current environment,
  and how to use them. Use when choosing a build/test/lint/format/decompile/
  config-validation command (Java/Maven, Rust/cargo, TypeScript, or general), or when
  asked what dev tools are available.
---

# Dev Tooling

Find the right dev tool fast: know what is actually here, and how to use it. Prefer the
system tools below over installing duplicates via npm/cargo/pip. No LSP is wired up here —
use the build/lint/test commands as your code feedback.

Two sources of truth, never one:
- **Presence** (is a tool here?) → the probe, `discover.sh`.
- **Usage** (how do I call it, what to watch for?) → the catalog below.

## Workflow

1. **Probe once.** Run `bash <skill-dir>/discover.sh` and read the three lines.
   *Done when* you hold the `PRESENT:`, `runtime:`, and `env:` lines. Re-run only if the
   environment changes (different container, user switches machines). (If the probe itself
   cannot run, fall back to checking each catalog tool individually.)
2. **Pick from the catalog**, constrained to the tools on the `PRESENT:` line.
3. **Preferred tool absent?** Use its fallback (below). If nothing reasonable exists,
   **ask before installing** anything.
4. **Don't re-guess** a tool you've already probed — trust the probe.

`<skill-dir>` is the directory containing this SKILL.md (it also holds `discover.sh`). The
probe's commented `TOOLS` table is the single source of truth for *what is looked for*; the
catalog below is the single source of truth for *how each tool is used*.

### Reading the probe

- `PRESENT: …` — the tools you may use. Anything not listed is **absent**: don't call it.
- `runtime: …` — versions of `java` / `cargo` / `node` / `py`.
- `env: …` — OS, user, `JAVA_HOME`, and `net` (`up` / `down` / `unknown`). `net=down` means
  first builds that download dependencies (Maven Central, crates.io, npm) will fail — say so
  before starting them.

## Catalog

Each entry: role — canonical command — caveat. Presence is decided by the probe, not stated
here, so an entry may describe a tool that is absent in your environment.

### Java / Maven

- **java / javac** — compile & run.
- **mvn** — build; build-time diagnostic: `mvn -q compile` (exit code + errors = compiler
  feedback). First run downloads from Maven Central (needs `net=up`).
- **cfr** — decompiler: read library source with `cfr Foo.class` or
  `cfr lib.jar --outputdir ./src`.
- **javap** — disassemble bytecode: `javap -p Foo.class`.
- **jdeps** — analyze class/package dependencies.
- **jshell** — interactive Java REPL.
- **jar / javadoc / jlink** — jar archives, API docs, minimal runtime images.

### Rust

- **rustc / cargo** — build & test. First build fetches crates from crates.io (needs `net=up`).
- **cargo clippy** — lint / build-time diagnostic: `cargo clippy --all-targets`.
- **cargo fmt** — `cargo fmt --check` (verify) or `cargo fmt` (apply).
- **cargo nextest** — fast parallel tests, better failure output: `cargo nextest run`.
- **taplo** — TOML: `taplo check Cargo.toml`, `taplo format -i Cargo.toml`.
- **cargo audit** — RUSTSEC security advisories for lockfile dependencies.
- **cargo deny** — license and dependency checks: `cargo deny check`.
- **cargo udeps** — detect unused dependencies.
- **wasm-pack / wasm-bindgen** — Wasm packaging workflow.
- **wasm-tools** — inspect Wasm binaries: `wasm-tools print foo.wasm`.
- **dx** (dioxus-cli) — Dioxus apps: `dx new`, `dx serve`, `dx build`.
- **rust-analyzer** — LSP binary (not wired to this harness).

### TypeScript / JavaScript

- **tsc** — build-time diagnostic: `tsc --noEmit`.
- **prettier** — formatter: `prettier --check .`, `prettier --write .`.
- **biome** — linter + formatter, no config needed: `biome check .`.
- **eslint** — flat config (`eslint.config.js`).
- **esbuild** — run/bundle TS without npm setup: `esbuild app.ts --bundle --platform=node`.
- **ts-node** — run `.ts` files directly.
- **node / npm** — runtime. A project's own toolchain comes from its `package.json` /
  `node_modules`.

### Config validation (XML / YAML / JSON)

- **yamllint** — YAML syntax/style; non-zero exit on invalid: `yamllint file.yml`.
- **yq** — read/transform YAML or JSON: `yq '.version' f.yml`, `yq -o=json f.yml`.
- **xmlstarlet** — XPath queries: `xmlstarlet sel -t -v 'project.version' pom.xml`.
- **xmllint** — XML well-formedness; non-zero on invalid: `xmllint --noout file.xml`.
- **jq** — JSON queries: `jq '.dependencies' package.json`.

### General

- **git** — version control.
- **rg** — fast code search. **fd** — fast file search.
- **shellcheck** — shell-script lint.
- **just** — task runner: `just --list`.
- **python3 / uv** — Python + fast package manager. **pypdf** (Python library,
  `import pypdf`) for PDFs.
- **gcc / make** — C/C++ toolchain.
- **magick** — ImageMagick image manipulation.
- **godot** — Godot game engine.

## Fallbacks

Use the preferred tool when present; otherwise step down the list. If nothing reasonable is
available, **ask before installing** anything.

- **Rust tests:** `cargo nextest` → `cargo test`.
- **Rust lint:** `cargo clippy` → `cargo build` (read the warnings).
- **TS lint/format:** `biome` → `eslint` + `prettier`.
- **TOML:** `taplo` → `python3 -c "import tomllib"` (stdlib, read-only).
- **YAML:** `yamllint` / `yq` → `python3 -c "import yaml"`.
- **JSON:** `jq` → `python3 -c "import json"`.
- **Java build:** `mvn` → `javac` directly.
