# agentskills

A curated collection of AI agent skills. Some are original, others are modified from great work by the community. Everything lives here for easy management and consistent workflow.

## Workflow

The skills shape a spec-driven development loop:

1. **Refine** — start from an idea or a simple spec. The `refine` skill
   interviews you through the design decisions, one at a time, until the
   result is an implementation-ready design spec in `docs/plans/`.
2. **Plan & implement** — `planning-with-files` turns the design into a
   file-based plan in `.planning/`, broken into phases. The plan files act
   as working memory on disk, so the task survives context compaction and
   session breaks.
3. **Review & commit** — when implementation is done, the changes are
   staged and the `review` skill reviews them. Critical, high, or medium
   findings trigger a fix round and a re-review; the loop repeats until the
   report is clean, then the changes are committed. Findings reports land
   in `docs/reviews/`.

`caveman-commit` words the commit message; the language guideline skills
(`rust-guidelines`, `typescript-guidelines`, `java-guidelines`) feed the
review's compliance pass.

| Skill | Description | Source |
| --- | --- | --- |
| arch-review | Architecture review for any Rust codebase — modularization, separation of concerns, call hierarchy, memory, performance, inconsistencies. | self |
| caveman-commit | Generate commit messages | [Caveman-Skills](https://github.com/JuliusBrussee/caveman) |
| dev-tooling | Discover which dev tools are actually available and how to use them — a portable tool catalog plus a live environment probe. | self |
| java-guidelines | Enforces Google Java Style Guide discipline with guideline files. | Converted from the [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html) (CC BY 3.0) |
| planning-with-files | Organize implementations by file based planning; lifecycle hooks keep the plan in context every turn (Respondami adaptation) | [planning-with-files](https://github.com/OthmanAdi/planning-with-files/) adapted for Respondami: frontmatter hook matchers, hard template reading, phase gate, dead content removed, mechanical hook log + smart plan head for local LLMs |
| refine | Explore user intent and requirements to create a design spec. | Mostly self, with inspiration from Reddit and the grill-me skill by [Matt Pocock](https://github.com/mattpocock/skills) |
| review | Systematic multi-pass code review (Rust, TypeScript, Java) — whole project, single file, or changeset. | self |
| rust-guidelines | Enforces Microsoft-style Rust development discipline with guideline files. | [ms-rust-skill](https://gitlab.com/lx-industries/ms-rust-skill) with some minor modifications |
| typescript-guidelines | Enforces Google TypeScript Style Guide discipline with guideline files. | Converted from the [Google TypeScript Style Guide](https://tsguide.google.com) (CC BY 3.0) |
| writing-great-skills | Reference for writing and editing skills well | By [Matt Pocock](https://github.com/mattpocock/skills) |

> **Note:** This is an early-stage project. The long-term goal is a complete
> skill-based spec-driven development (SDD) workflow.
>
> **Current state & roadmap:**
> - The refine → planning-with-files → review loop works end-to-end,
>   including the review gate's fix rounds.
> - Requirements gathering needs more structure — likely a dedicated skill,
>   separate from refine.
