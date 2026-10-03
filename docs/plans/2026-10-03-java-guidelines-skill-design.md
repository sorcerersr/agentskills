# Design: `java-guidelines` skill

- **Date:** 2026-10-03
- **Status:** Validated (all sections approved by user)
- **Location of work:** `agentskills/java-guidelines/` (dev checkout `/home/dev/github/agentskills`)
- **Source material:** `styleguide/javaguide.html` (Google Java Style Guide, CC BY 3.0)

## Purpose

Create a new agent skill `java-guidelines` in the `agentskills` repo that enforces the
Google Java Style Guide on any Java code an agent writes or modifies. It mirrors the
existing `rust-guidelines` and `typescript-guidelines` skills: a `SKILL.md` that is always
in context (mandatory workflow + file map + coding rules) and a set of guideline files the
agent loads on demand. Content is a **verbatim** HTML→Markdown conversion of the guide.

## Validated decisions

| # | Decision | Choice |
| --- | --- | --- |
| 1 | Content fidelity | Verbatim full conversion of the entire guide (no curation, no quick-reference addendum) |
| 2 | File split | One file per top-level section (§2–§7) → 6 files; §1 (Introduction) moves into SKILL.md |
| 3 | SKILL.md beyond the guide | Include a short "Tooling" note (project formatters govern formatting) |
| 4 | Section numbers / cross-refs | Keep numbers in headings; 29 internal anchor links flattened to plain text |
| 5 | README table | Add `java-guidelines` row **and** the missing `typescript-guidelines` row in the same commit |

## Section A: Skill structure and files

```
agentskills/java-guidelines/
├── SKILL.md
├── 01_source_file_basics.md       ← guide §2
├── 02_source_file_structure.md    ← guide §3
├── 03_formatting.md               ← guide §4 (largest, ~60%)
├── 04_naming.md                   ← guide §5
├── 05_programming_practices.md    ← guide §6 (smallest)
└── 06_javadoc.md                  ← guide §7
```

Verbatim conversion with exactly two deviations (both validated):

1. **Section 1 (Introduction)** is moved into SKILL.md as a "Guide reference" section
   (§1.1 Terminology notes, §1.2 Guide notes, verbatim, renumbered `### 1.1`, `### 1.2`).
   Same treatment the TS skill gave its intro.
2. **Section numbers are kept in all headings** (`## 4.5 Line-wrapping`); the 29 internal
   anchor links become plain text (their link text is already descriptive, e.g.
   "Section 4.5"), so in-body references stay resolvable by eye.

Everything else is verbatim: all rules, rationale paragraphs, tips, examples. The 31 `<pre>`
code blocks become fenced code blocks (bad examples labeled, see Section C), the 2 tables
become Markdown tables, external links are kept, and the JS-generated TOC (empty in the
HTML) is dropped. Each file starts at its top-level section heading, so one loaded file is a
self-contained, section-numbered document. Total expected size: ~1,200–1,500 lines of
Markdown.

## Section B: SKILL.md content

**Frontmatter:**

```yaml
name: java-guidelines
description: ALWAYS invoke this skill BEFORE writing or modifying ANY Java
code (.java files) even for simple Hello World programs. Enforces Google
Java Style Guide discipline and requires consulting the appropriate
guideline files before any coding activity. This skill is MANDATORY for
all Java development.
```

**Header:**

- `**Guide snapshot: 2026-10-03 (google.github.io/styleguide/javaguide.html)**`
- HTML attribution comment: based on the Google Java Style Guide, CC BY 3.0
  (https://creativecommons.org/licenses/by/3.0/); converted from HTML to Markdown; the
  Introduction is moved into SKILL.md; all other content is verbatim.

**Mandatory Workflow** (same pattern as both blueprints): the skill must be invoked for
creating new `.java` files (even minimal examples), modifying any existing `.java` file, and
reviewing, refactoring, or rewriting Java code.

**File map — "Which guideline to read and when":**

| File | Use when |
| --- | --- |
| `01_source_file_basics.md` | creating new files; file names, UTF-8 encoding, special/Unicode characters |
| `02_source_file_structure.md` | organizing files: copyright header, package declaration, imports, class declaration, member ordering, module declaration |
| `03_formatting.md` | **ALL Java tasks**: braces, indentation, 100-column limit, line wrapping, whitespace, switch/enum/arrays/annotations/text blocks |
| `04_naming.md` | **ALL Java tasks**: packages, classes, methods, constants, fields, parameters, type variables |
| `05_programming_practices.md` | unused imports/warnings, caught exceptions, static member access, finalizers |
| `06_javadoc.md` | writing or updating Javadoc; deciding where Javadoc is required |

**Coding Rules:**

1. Load the applicable guideline files BEFORE any Java code generation.
2. Respect the guide's normative language: *must* = required, *should*/*should not* =
   prefer/avoid, *may* = optional. (Stated as interpretation — this guide, unlike the TS
   guide, never defines RFC 2119.)
3. Defer to the project formatter for formatting (see Tooling note).
4. Comments must ALWAYS be written in American English, unless the user explicitly requests
   a different language.

**Guide reference section:** verbatim §1.1 Terminology notes + §1.2 Guide notes, followed by
a short **Tooling** subsection: the formatting rules are designed to be enforced by tooling
(Google Java Format, Checkstyle with Google checks); when the project uses one, follow its
output for formatting — the guide governs everything tooling does not.

## Section C: Conversion conventions (HTML → Markdown)

One-off converter script (Python stdlib `html.parser`, ~150–200 lines), run over
`styleguide/javaguide.html`, output split at `h2` boundaries into the 6 files. Fixed mapping:

**Structure**

- `h2 → #`, `h3 → ##`, `h4 → ###`, `h5 → ####` (each file's top section is `#`, numbers intact).
- Collapse intra-paragraph line breaks (the HTML hard-wraps at ~90 columns mid-sentence).
- Unescape HTML entities (`-&gt;` → `->`, `&amp;` → `&`); `<strong>` → `**bold**`, `<em>` → *italics*.
- Drop: `<h1>` title, empty JS TOC div, script/style tags, wrapper divs.

**Code**

- `<pre class="prettyprint lang-java">` → unlabeled \`\`\`java fence (31 pre blocks total).
- `<pre … badcode>` and `<pre class="bad">` → `**Bad:**` label + fence; `<pre class="good">`
  → `**Good:**` + fence (TODO-comment examples in §4.8.6.2 carry no language tag → untagged fence).
- Inline `<code>` → backticks; inline `<code class="badcode">` (24 occurrences, e.g. `\012`)
  → `~~\012~~` strikethrough (TS precedent for bad inline code).

**Other**

- `<p class="tip">` → blockquote `> **Tip:** …` (same as TS Tips).
- Ordered/unordered lists → `1.` / `-`.
- The 2 tables → pipe tables.
- External links kept as-is; internal `#s…` anchors → plain text (link target only).

Result: faithful, mechanically reproducible Markdown with zero editorial changes.

## Section D: Build process, verification, rollout

**Build order** (all in `/home/dev/github/agentskills`):

1. Write the converter script; run it; split output at `h2` into the 6 numbered files.
2. Author `SKILL.md` by hand (Section B).
3. Run verification (below).
4. Update `agentskills/README.md`: add the `java-guidelines` row and the missing
   `typescript-guidelines` row (source: Google Java Style Guide, verbatim).
5. Commit; `git pull` in the live checkout `~/.config/respondami/skills` (same origin,
   both at `8f15caf` → clean fast-forward) so Respondami discovers the skill.

**Verification** (mechanical checks, no test framework — docs skill):

- *Completeness:* all 59 section headings in the HTML appear, in order, in the 6 files or
  in SKILL.md (automated diff of heading lists).
- *Element counts:* 31 `<pre>` → 31 fences; 24 inline `badcode` → 24 strikethroughs;
  2 tables → 2 pipe tables; all external URLs preserved.
- *No residue:* zero hits for `<pre`, `class=`, `href=`, `&amp;`, or other HTML artifacts.
- *Frontmatter:* `name` matches directory; description single-line.
- *Manual spot-checks:* §2.3.3 escape tables, §4.8.4 switch blocks, §4.8.6.2 TODO
  Good/Bad labels, §5.3 camel case.

On any failed check: fix the converter and re-run — never hand-edit output, keeping the
conversion reproducible.

**Rollout note:** the skill becomes visible to Respondami after the live checkout pull, in
the next session.

## Out of scope (YAGNI)

- No curation/summarization of the guide; no quick-reference addendum in SKILL.md.
- No additional "best practices" content beyond the guide (unlike the Rust skill's broader
  scope); no Java-specific tooling setup instructions beyond the 2–3 sentence note.
- No test harness, no CI for the docs.
