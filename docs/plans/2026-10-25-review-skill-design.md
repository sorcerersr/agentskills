# Review Skill Design

Extends the `code-health-check` skill into a multi-language, multi-scope review skill renamed `review`.

## 1. Skill identity & file layout

The skill is renamed `code-health-check` → `review`, living at `/home/dev/agentskills/review/` (the old directory is removed; the installed copy under `~/.config/respondami/skills/` is updated to match). It stays **user-invoked** (`disable-model-invocation: true`) with a one-line human-facing description:

> Systematic multi-pass code review (Rust, TypeScript, Java) — whole project, single file, or changeset. Outputs findings to `docs/reviews/`.

File layout:

```
review/
  SKILL.md          # language-agnostic: scope selection, Passes 0–2 categories,
                    # Pass 4 process, severities, finding format, report format
  rust.md           # Rust: Pass 0/3 details, Pass 1/2 language checks,
                    # Pass 4 → activate rust-guidelines
  typescript.md     # same shape → activate typescript-guidelines
  java.md           # same shape → activate java-guidelines
  scripts/
    precompact-emit.sh   # unchanged
```

`SKILL.md` contains everything every run needs: how to pick the scope mode, the pass matrix, the language-agnostic Pass 1/2 categories, the Pass 4 *process* (detect language → load language file → activate guidelines skill → topic-scan → load applicable guideline files → evaluate). The language files sit behind a context pointer that fires on language detection — a pure branch-based disclosure: a Java-only review never loads `rust.md` or the Rust guidelines. Each language file follows an identical internal shape (Pass 0 manifest, discovery command, Pass 1/2 checks, Pass 3 audit rules, Pass 4 loading rule), so the structure is predictable across all three.

### Pass 4 procedure (language-agnostic, in SKILL.md)

1. **Activate** the language's guidelines skill (named by the language file).
2. **Topic scan**: note which guideline topics are present in the in-scope code; load the "ALL tasks" files plus every matching file. *Completion criterion: every topic present in in-scope code has a loaded file or a noted reason it doesn't apply.*
3. **Rule inventory**: extract the normative rules (`must`/`must not`/`should`/`should not`) from each loaded file.
4. **Evaluate every in-scope file against every rule** — same exhaustive discipline as Passes 1–2.
5. **Tooling precedence**: check the project's tooling config first (named per language in the language file: clippy, Prettier/ESLint, google-java-format/Checkstyle). Rules the tooling enforces are out of scope.
6. **Consistency policy**: if the codebase *consistently* deviates from a rule (an established local convention), report it once as a Low "project convention deviates from guide" finding instead of one finding per occurrence.
7. **Non-normative examples**: optional formatting choices shown in guide examples are never enforced as rules.
8. **Findings**: standard format plus `Guideline: <lang> <file> §<rule>` citation; severity per the severity mapping (must → Medium, should → Low, must with bug risk → High).
9. The compliance table records which guideline files were loaded.

The language files add only: which guidelines skill to activate, the tooling configs to check, and a few language-specific review notes (e.g., Rust's M-CANONICAL-DOCS doc format; TS `@ts-ignore` as a must-violation).

## 2. Scope modes & language detection

The run starts by resolving the **scope mode** from the user's request:

| Mode | Trigger | In-scope files |
|------|---------|----------------|
| Project | `review` / "review the project" | every file with a supported extension |
| File | "review `src/foo.rs`" | that one file |
| Commit | "review commit `<sha>`" / "last commit" | `git show --name-only --format= <sha>`, filtered to supported extensions |
| Staged | "review staged changes" / "files to be committed" | `git diff --name-only --cached`, filtered to supported extensions |

Ambiguous requests get one clarifying question; a non-git repo with a changeset request stops with a clear message. If filtering leaves zero supported files, the skill stops with a clear message (no empty report).

**Language detection** is by extension: `.rs` → Rust; `.ts`/`.tsx`/`.mts`/`.cts` → TypeScript; `.java` → Java. Each detected language loads its language file. Mixed-language projects load several; a review of a single TS file in a mixed repo loads only `typescript.md`.

**Pass matrix** (per Q2):

| Pass | Project | File | Changeset |
|------|---------|------|-----------|
| 0 — project understanding | yes | yes (light) | yes |
| 1 — correctness | all files | the file | in-scope files |
| 2 — quality | all files | the file | in-scope files |
| 3 — dependency audit | yes | no | only if a manifest is in the changeset |
| 4 — guideline compliance | all files | the file | in-scope files |

Findings are reported only for in-scope files; call-path tracing for the "Verified" line may cross into out-of-scope code. Pass 0 in file/changeset mode is the same 3–5 context actions, narrowed to the relevant modules.

## 3. Passes 0–3 content split

**Pass 0 — Project understanding** (`SKILL.md`): the 3–5 context actions, generalized: read the project's manifest(s) and build files, inventory the module layout, read the README, check recent git history. Language files specify the concrete artifacts (Rust: `Cargo.toml` workspace/crates, `mod.rs` layout; TS: `package.json`, `tsconfig.json`, entry points; Java: `pom.xml`/`build.gradle`, package structure). The report header is created after Pass 0, as today, and `docs/reviews/.active_report` is written.

**Pass 1 — Correctness** (`SKILL.md` categories + language checks): the language-agnostic categories stay — logic errors, concurrency, error handling, data integrity, edge cases. Each language file adds a short "Pass 1 language checks" list with the concrete, language-typical bugs. The current Rust examples move to `rust.md` (`unwrap()`/`expect()` in production paths, `ok()`/`unwrap_or_default()` swallowing, channel misuse, `unsafe` soundness). TS gets `@ts-ignore`/`any` leakage, unhandled promises, unchecked `null`. Java gets caught-and-ignored exceptions, missing `@Override`, mutable static state.

**Pass 2 — Quality** (`SKILL.md` categories + language checks): same split — categories (naming, duplication, complexity, architecture, DRY) in `SKILL.md`; per-language concrete checks in the language files (kept short; deep naming/style rules live in the guidelines skills, which Pass 4 applies — Pass 2 stays at "quality issue that could cause bugs" altitude to avoid overlapping Pass 4).

**Pass 3 — Dependency audit** (fully in language files):
- Rust: the current audit verbatim (unused deps via `cargo tree`, dev-dep leakage, duplicate functionality, outdated majors, unused features, config issues).
- TypeScript: `package.json` — unused deps (cross-reference imports), dev-dep leakage into non-test code, duplicate functionality (two HTTP clients, two state libraries), direct vs. transitive imports of packages not declared.
- Java: `pom.xml`/`build.gradle` — unused declared dependencies, duplicate functionality, conflicting versions across modules, scope issues (`test`-scoped deps used in main).

In changeset mode, Pass 3 audits only the changed manifest entries.

## 4. Severities, findings & report format

**Severity definitions** (unchanged from the current skill): Critical / High / Medium / Low with the same criteria table. Pass 4 adds the Q6 mapping on top: `must` → Medium, `should` → Low, `must` with bug risk → High. Guideline violations never reach Critical.

**Finding format** (unchanged + one line):

```markdown
### [SEV-N] Short title
- **Location**: `path/file.ext:line` — function name (lines ~X-Y)
- **Issue**: What's wrong, described concisely
- **Why it matters**: Impact — what breaks, when, and how
- **Suggested fix**: Concrete code change or refactoring approach
- **Guideline**: rust 08_universal §Error handling   ← Pass 4 findings only
```

Critical/High findings keep the `Verified:` line. Prefixes `C-`/`H-`/`M-`/`L-`, numbered per severity, as today.

**Report** (`docs/reviews/YYYY-MM-DD-<suffix>-review.md` per Section 2):

1. **Header**: scope mode, scope target (file path / commit SHA / "staged"), languages detected, file count + LOC in scope, focus, methodology.
2. **Findings**: one list, grouped Critical → Low, all passes mixed.
3. **Compliance table** (per language): guideline files loaded, must-violation count, should-violation count.
4. **Dependency audit table**: dep name, status, notes — only when Pass 3 ran.
5. **Summary table**: severity counts.

Findings are appended to the report as they are generated (incremental build, as today). On completion: summary tables appended, `docs/reviews/.active_report` cleared. The PreCompact hook and `precompact-emit.sh` are unchanged — the hook keeps working because the state-file contract is unchanged.

The Scope section of `SKILL.md` is rewritten: in scope = correctness, quality, dependency audit, guideline compliance; out of scope = performance optimization, tooling-enforced formatting, documentation completeness beyond guideline rules, test coverage, security audit.

## 5. Validation & migration

**Validation matrix** — run the skill on small sample projects/inputs covering every branch:

1. Rust project, whole-project mode
2. TypeScript project, whole-project mode
3. Java project, whole-project mode
4. Single Rust file, file mode
5. Staged changeset (Rust)
6. Commit changeset (TS)
7. Project with no supported language → clean stop, no report
8. Mixed-language project → both language files load, per-language compliance tables

Per run, check: correct language file(s) loaded; correct passes ran per the matrix; report name correct (incl. same-day counter); `.active_report` set after Pass 0 and cleared on completion; guideline files loaded match the topic scan; findings carry `Guideline:` citations where applicable.

**Migration steps:**

1. Create `review/` from `code-health-check/` (move `SKILL.md` + `scripts/`).
2. Rewrite `SKILL.md` per Sections 1–4; write `rust.md` (absorbing the current Rust-specific content: Pass 0 Cargo details, Pass 1 Rust examples, Pass 3 verbatim), `typescript.md`, `java.md`.
3. Update the frontmatter: `name: review`, new human-facing description, keep `disable-model-invocation: true` and the PreCompact hook.
4. Remove `code-health-check/` from the source repo; update the installed copy under `~/.config/respondami/skills/` (add `review/`, remove `code-health-check/`).
5. Check for references to `code-health-check` elsewhere in the repo (README, other skills) and update them.
6. Commit.

**YAGNI notes:** no JS/other-language support, no untracked-file or range changesets, no scripted test harness, no model-invocation.
