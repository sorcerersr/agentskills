---
name: typescript-guidelines
description: ALWAYS invoke this skill BEFORE writing or modifying ANY TypeScript code (.ts, .tsx, .mts, .cts files) even for trivial examples. Enforces Google TypeScript Style Guide discipline and requires consulting the appropriate guideline files before any coding activity. This skill is MANDATORY for all TypeScript development.
---

**Guide snapshot: 2026-09-23 (tsguide.google.com)**

# TypeScript Development Skill

<!-- Based on the Google TypeScript Style Guide (https://tsguide.google.com),
licensed under CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/).
This copy is converted from HTML to Markdown; the Introduction and Toolchain
requirements sections are moved into SKILL.md and all other content is
verbatim. -->

This skill enforces structured, guideline-driven TypeScript development. It ensures all TypeScript code strictly follows the Google TypeScript Style Guide rules for language features, types, naming, file structure, and documentation.

## Mandatory Workflow

**This skill MUST be invoked for ANY TypeScript action**, including:

- Creating new `.ts`, `.tsx`, `.mts`, or `.cts` files (even minimal examples)
- Modifying existing TypeScript files (any change, no matter how small)
- Reviewing, refactoring, or rewriting TypeScript code

## Which guideline to read and when

Before writing or modifying TypeScript code, **the agent must load ONLY the guideline files that apply to the requested task**, using segmented reading (`offset` and `limit`) when needed.

### Guidelines and when they apply

#### 1. `01_language_features.md`

Use in ALL TypeScript tasks. Covers classes, functions, `this`, interfaces, primitive literals, control structures, iterators, decorators, and disallowed features.

#### 2. `02_type_system.md`

Use when defining types or interfaces, dealing with `null`/`undefined`, using generics, considering `any` or `{}`, working with tuples and array types, or suppressing type errors with `@ts-ignore`.

#### 3. `03_naming.md`

Use in ALL TypeScript tasks. Defines identifier naming rules by identifier type (variables, constants, functions, classes, types, files, test names).

#### 4. `04_source_file_structure.md`

Use when creating new files, reorganizing imports and exports, writing file headers (copyright, `@fileoverview`), or choosing import/export forms.

#### 5. `05_comments_documentation.md`

Use when writing JSDoc, documenting exports, classes, methods, or parameters, or adding implementation comments.

#### 6. `06_policies.md`

Use when modifying existing code, reformatting legacy code, deprecating APIs, or working with generated code.

## Coding Rules

1. **Load the necessary guideline files BEFORE ANY TYPESCRIPT CODE GENERATION.**
2. Respect the guide's normative language: `must`/`must not`, `should`/`should not` (prefer/avoid), and `may` per RFC 2119.
3. Project tooling (Prettier, ESLint, tsconfig, `.editorconfig`) takes precedence where it governs; the guide covers everything else (naming, types, documentation, API shape).
4. When modifying existing code, follow `06_policies.md` — consistency with the surrounding code first.
5. Comments must ALWAYS be written in American English, unless the user explicitly requests a different language.

## Guide reference

### Terminology notes

This Style Guide uses [RFC 2119](https://tools.ietf.org/html/rfc2119) terminology when using the phrases *must*, *must not*, *should*, *should not*, and *may*. The terms *prefer* and *avoid* correspond to *should* and *should not*, respectively. Imperative and declarative statements are prescriptive and correspond to *must*.

### Guide notes

All examples given are **non-normative** and serve only to illustrate the normative language of the style guide. That is, while the examples are in Google Style, they may not illustrate the *only* stylish way to represent the code. Optional formatting choices made in examples must not be enforced as rules.

### Toolchain requirements

Google style requires using a number of tools in specific ways, outlined here.

### TypeScript compiler

All TypeScript files must pass type checking using the standard tool chain.

#### @ts-ignore

Do not use `@ts-ignore` nor the variants `@ts-expect-error` or `@ts-nocheck`.

**Why?**

They superficially seem to be an easy way to “fix” a compiler error, but in practice, a specific compiler error is often caused by a larger problem that can be fixed more directly.

For example, if you are using `@ts-ignore` to suppress a type error, then it's hard to predict what types the surrounding code will end up seeing. For many type errors, the advice in how to best use `any` is useful.

You may use `@ts-expect-error` in unit tests, though you generally *should not*. `@ts-expect-error` suppresses all errors. It's easy to accidentally over-match and suppress more serious errors. Consider one of:

- When testing APIs that need to deal with unchecked values at runtime, add casts to the expected type or to `any` and add an explanatory comment. This limits error suppression to a single expression.

- Suppress the lint warning and document why, similar to suppressing `any` lint warnings.

### Conformance

Google TypeScript includes several *conformance frameworks*, [tsetse](https://tsetse.info) and [tsec](https://github.com/google/tsec).

These rules are commonly used to enforce critical restrictions (such as defining globals, which could break the codebase) and security patterns (such as using `eval` or assigning to `innerHTML`), or more loosely to improve code quality.

Google-style TypeScript must abide by any applicable global or framework-local conformance rules.
