# Design: README workflow section (refine → planning-with-files → review)

## Context

Update `README.md` to describe the end-to-end workflow shaped by the three skills, per the user's mental model: idea/spec → refine (design decisions) → implementation-ready design spec → file-based phased plan → review of the changes. Designed after the review gate landed (commit 8f49217).

Decisions locked during brainstorming:

- D1: full review-gate loop described briefly (staging, C/H/M fix rounds, commit on clean report)
- D2: new "Workflow" section after the intro, before the skill table; stale roadmap note updated
- D3: one supporting line for caveman-commit + language guideline skills

## 1. The new "Workflow" section (proposed text)

Placed after the intro paragraph, before the skill table:

```markdown
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
```

~150 words, three numbered stages matching the user's mental model, the fix loop made visible, and the concrete artifacts (`docs/plans/`, `.planning/`, `docs/reviews/`) named so readers can see the workflow's traces in a repo.

## 2. Roadmap note update

The current note's last bullet is now false. The note becomes:

```markdown
> **Note:** This is an early-stage project. The long-term goal is a complete
> skill-based spec-driven development (SDD) workflow.
>
> **Current state & roadmap:**
> - The refine → planning-with-files → review loop works end-to-end,
>   including the review gate's fix rounds.
> - Requirements gathering needs more structure — likely a dedicated skill,
>   separate from refine.
```

What changes and why:

- "Refine → Implement flow works well end-to-end" and "Planning-with-files handles implementation well, especially for local LLMs" are absorbed into the first bullet — the loop is the current state, and the local-LLM detail is a property of one skill (the table's planning-with-files row already carries the adaptation notes).
- "Review & verification is the major missing piece" is deleted — the review skill and the review gate closed it.
- The requirements-gathering bullet stays; it's still true.
- The "Some pieces are still missing, but the foundation is laid" sentence is dropped: the remaining gap (requirements structure) is stated explicitly, so the vague hedge is a no-op.

Everything else in the README — the skill table, the intro, the sources — is untouched.
