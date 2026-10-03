---
name: java-guidelines
description: ALWAYS invoke this skill BEFORE writing or modifying ANY Java code (.java files) even for simple Hello World programs. Enforces Google Java Style Guide discipline and requires consulting the appropriate guideline files before any coding activity. This skill is MANDATORY for all Java development.
---

**Guide snapshot: 2026-10-03 (google.github.io/styleguide/javaguide.html)**

# Java Development Skill

<!-- Based on the Google Java Style Guide (https://google.github.io/styleguide/javaguide.html),
licensed under CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/).
This copy is converted from HTML to Markdown; Section 1 (Introduction) is moved
into SKILL.md and all other content is verbatim. -->

This skill enforces structured, guideline-driven Java development. It ensures all Java code strictly follows the Google Java Style Guide rules for source file basics, source file structure, formatting, naming, programming practices, and documentation.

## Mandatory Workflow

**This skill MUST be invoked for ANY Java action**, including:

- Creating new `.java` files (even minimal examples)
- Modifying existing Java files (any change, no matter how small)
- Reviewing, refactoring, or rewriting Java code

## Which guideline to read and when

Before writing or modifying Java code, **the agent must load ONLY the guideline files that apply to the requested task**, using segmented reading (`offset` and `limit`) when needed.

| File | Use when |
| --- | --- |
| `01_source_file_basics.md` | creating new files; file names, UTF-8 encoding, special and Unicode characters |
| `02_source_file_structure.md` | organizing files: copyright header, package declaration, imports, class declaration, class contents ordering, module declaration |
| `03_formatting.md` | **ALL Java tasks**: braces, indentation, 100-column limit, line wrapping, whitespace, and the rules for switch, enum, arrays, annotations, comments, modifiers, and text blocks |
| `04_naming.md` | **ALL Java tasks**: package and module names, classes, methods, constants, fields, parameters, type variables, camel case |
| `05_programming_practices.md` | `@Override`, caught exceptions, static member access, finalizers |
| `06_javadoc.md` | writing or updating Javadoc; deciding where Javadoc is required |

## Coding Rules

1. **Load the necessary guideline files BEFORE ANY JAVA CODE GENERATION.**
2. Respect the guide's normative language: *must* = required, *should*/*should not* = prefer/avoid, *may* = optional.
3. For formatting, defer to the project formatter when one is in use (see [Tooling](#tooling)); the guide governs everything the tooling does not.
4. Comments must ALWAYS be written in American English, unless the user explicitly requests a different language.

## Guide reference

### 1.1 Terminology notes

In this document, unless otherwise clarified:

1. The term *class* is used inclusively to mean a normal class, record class, enum class, interface or annotation type (`@interface`).
2. The term *member* (of a class) is used inclusively to mean a nested class, field, method, *or constructor*; that is, all top-level contents of a class except initializers.
3. The term *comment* always refers to *implementation* comments. We do not use the phrase "documentation comments", and instead use the common term "Javadoc."

Other "terminology notes" will appear occasionally throughout the document.

### 1.2 Guide notes

Example code in this document is **non-normative**. That is, while the examples are in Google Style, they may not illustrate the *only* stylish way to represent the code. Optional formatting choices made in examples should not be enforced as rules.

### Tooling

The formatting rules of this guide are designed to be enforced by tooling, such as [Google Java Format](https://github.com/google/google-java-format) or Checkstyle configured with the Google checks. When the project uses one of these, follow its output for formatting.
