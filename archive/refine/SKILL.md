---
name: refine
description: "Use this skill before any creative work. Activate it with `activate_skill` first, then follow its instructions to explore user intent, requirements and design before implementation."
---

# Brainstorming and refining Ideas Into Designs

## Overview

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, Then interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.
If a question can be answered from the resources available to you, answer it that way instead of asking.
 Once you understand what you're building, present the design in small sections (200-300 words), checking after each section whether it looks right so far.

## The Process

**Understanding the idea:**

- Check out the current project state first (files, docs, recent commits)
- Ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on understanding: purpose, constraints, success criteria

**Exploring approaches:**

- Propose 2-3 different approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why

**Presenting the design:**

- Once you believe you understand what you're building, present the design
- Break it into sections of 200-300 words
- Ask after each section whether it looks right so far - Ask for approval before continuing.
  If the user requests changes:
  1. Ask targeted follow-up questions to resolve the disagreement.
  2. Re-Plan the section
  3. Show the updated plan and ask for approval again.

  Repeat until the user approves.

- Cover: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

## After the Design

**Documentation:**

- Write the validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Present the user a summary of the design.

**Implementation Boundary (CRITICAL):**

- **Under no circumstances** should implementation begin without explicit user approval.
- After presenting the summary, **stop**!
- Do not start coding, creating files, or making any changes based on the design alone.
- When the user explicitly asks to implement, activate the `planning-with-files` skill and use the design document as the basis for the implementation plan.
- Explicitly state: "Design is complete and ready for futher review.

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design in sections, validate each
- **Be flexible** - Go back and clarify when something doesn't make sense
- **Always create the design document** - Don't skip creating the `docs/plans/YYYY-MM-DD-<topic>-design.md` file
- **Never start implementation** - The refine skill ends with a design document and a summary. Implementation is a separate phase that requires explicit user command.
