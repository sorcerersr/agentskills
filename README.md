# agentskills

A curated collection of AI agent skills. Some are original, others are modified from great work by the community. Everything lives here for easy management and consistent workflow.

| Skill | Description | Source |
| --- | --- | --- |
| arch-review | Architecture review for any Rust codebase — modularization, separation of concerns, call hierarchy, memory, performance, inconsistencies. | self |
| caveman-commit | Generate commit messages | [Caveman-Skills](https://github.com/JuliusBrussee/caveman) |
| code-health-check | Code review for any Rust project — correctness, quality, and dependency audit. | self |
| planning-with-files | Organize implementations by file based planning | [planning-with-files](https://github.com/OthmanAdi/planning-with-files/) with some small modifications |
| refine | Explore user intent and requirements to create a design spec. | Mostly self, with inspiration from Reddit and the grill-me skill by [Matt Pocock](https://github.com/mattpocock/skills) |
| rust-guidelines | Enforces Microsoft-style Rust development discipline with guideline files. | [ms-rust-skill](https://gitlab.com/lx-industries/ms-rust-skill) with some minor modifications |
| writing-great-skills | Reference for writing and editing skills well | By [Matt Pocock](https://github.com/mattpocock/skills) |

> **Note:** This is an early-stage project. The long-term goal is a complete skill-based spec-driven development (SDD) workflow. Some pieces are still missing, but the foundation is laid.
>
> **Current state & roadmap:**
> - **Refine → Implement** flow works well end-to-end.
> - Requirements gathering needs more structure — likely a dedicated skill, separate from refine.
> - **Planning-with-files** handles implementation well, especially for local LLMs with limited context windows (sessions split cleanly by phase).
> - **Review & verification** is the major missing piece — needs a skill to validate implementations against specs.
