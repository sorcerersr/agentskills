# Design: `dev-tooling` skill

- **Date:** 2026-10-05
- **Status:** Validated (all sections approved by user)
- **Location of work:** `agentskills/dev-tooling/` (dev checkout `/home/dev/agentskills`)
- **Source material:** `devtooling_skill_draft.md` (untracked draft, the "reference container" tool catalog)
- **Live discovery dir:** `~/.config/respondami/skills/` (Respondami picks up the skill after a pull)

## Purpose

Create a new agent skill `dev-tooling` that lets a coding agent **find available dev
tools faster than guessing**. The value comes from a "reference container" where a known
set of tools (Java/Maven, Rust/cargo, TypeScript, config validators, general utilities)
is exactly available.

The draft it is based on is a **static "what's installed" catalog**. Verification in the
reference container proved such a catalog goes stale and misleads:

- `jdeps`, `jshell` — listed as installed, but **absent**.
- `nextest`, `clippy`, `cargo audit/deny/udeps` — not bare binaries; they are
  `cargo-*` subcommands (`cargo nextest` works; `command -v nextest` fails).
- `pypdf` — a Python **library**, not a CLI binary (`command -v pypdf` fails;
  `python3 -c "import pypdf"` works).

The skill must (a) keep the high-value, portable "how to use these tools" knowledge, and
(b) work correctly in **any** environment by discovering what is *actually* present rather
than trusting a static list.

## Validated decisions

| # | Decision | Choice |
| --- | --- | --- |
| 1 | Core architecture | **Hybrid** — a portable "what & how" catalog (`SKILL.md`) + a live discovery probe (`discover.sh`). **Presence = the probe** (source of truth); **usage = the catalog**. |
| 2 | Fallback behaviour | **Group-level fallback** for the real branches (e.g. `nextest`→`cargo test`, `biome`→`eslint`+`prettier`) + a general rule: *preferred tool absent → closest standard alternative; if none reasonable, **ask before installing**.* |
| 3 | Probe location | **Self-documenting `discover.sh`** — a commented, type-aware detection table that is both the executable probe and the single source of truth for per-tool detection. Cheapest option (~60–70 tokens/session). |

**Decided from context (baked into the sections, not separately voted):**

- **Model-invoked** skill — the agent must reach it autonomously when choosing a tool.
- **Discovery scope** is *confirm the known set*, not open-ended discovery of arbitrary tools.
- **Session caching** — run the probe once per session, trust it; re-run only on an
  environment change.
- **Environment facts move out of the catalog into the live probe** (OS, user,
  `JAVA_HOME`, network) so they are reported fresh, never asserted.
- **The catalog makes no "installed here" claims** — this is the staleness fix.

## Section A: Architecture — two layers

The skill separates two things the draft had mixed:

**Layer 1 — Catalog (stable, portable), in `SKILL.md`.** Only knowledge true in *every*
environment:
- per task → preferred tool + canonical invocation;
- caveats (e.g. "first `mvn` build needs network");
- **group-level fallbacks** (Rust tests: `nextest`→`cargo test`; TS lint:
  `biome`→`eslint`+`prettier`);
- per tool: *how to check whether it is present* (the detect check).

The catalog makes **no** "installed here" claims. It is the source for ***what & how***.

**Layer 2 — Discovery (live, environment-specific), in `discover.sh`.** Runs **once per
session**, reports the *current truth*: which tools are actually present, plus runtime
versions (`java`/`cargo`/`node`/`py`) and env facts (OS, user, `JAVA_HOME`, network). It is
the source for ***what is here right now***.

**Sources of truth:** presence = the probe; usage = the catalog. The agent never derives
*both* from one source — that is what prevents the staleness bug (a catalog entry can list a
tool even when it is absent; the probe reports the truth).

**The lever vs. blind guessing:** instead of 15–30 sequential `command -v` guesses
(one round-trip each), the agent makes **one** compact probe (~60–70 tokens) that confirms
the *whole* known set at once.

## Section B: Components and file structure

```
agentskills/dev-tooling/
├── SKILL.md       # frontmatter + workflow + catalog (portable)
└── discover.sh    # self-documenting probe; single source of truth for detection
```

**`SKILL.md`**

- **Frontmatter:** `name: dev-tooling`; a model-invoked `description` with triggers
  (choosing build/test/lint/format/decompile/config-validation commands; "what tools are
  available?").
- **Workflow (in-skill steps):**
  1. Run `discover.sh` **once** — *completion criterion:* the `PRESENT`/`runtime`/`env`
     line is in hand.
  2. Pick the tool from the catalog, **constrained to the present set**.
  3. Preferred absent → group fallback → general rule → **ask before installing**.
  4. Trust the probe for the session; re-run only on an environment change.
- **Catalog (portable):** grouped by task area (Java/Maven, Rust, TS/JS, Config, General).
  Each entry: *tool — role — canonical invocation — caveat.* **No "installed here" claims.**
- **Fallbacks:** a short group-level list.

**`discover.sh`**

- **Self-documenting:** a commented table up top (`# nextest → command -v cargo-nextest`),
  so it is both readable and executable.
- **The detection list is the single source of truth** — mirroring the per-tool checks in
  the catalog.
- **Type-aware detection:** binary → `command -v X`; cargo subcommand → `command -v
  cargo-X`; python library → `python3 -c "import X"`.
- Emits **3 compact lines:** `PRESENT: …`, `runtime: …`, `env: …`.

**Structural move from the draft:** the old `Environment` section (user, `JAVA_HOME`,
"network available") moves **out** of the catalog **into** the probe, which reports those
facts live instead of asserting them as static truth.

## Section C: Data flow (end-to-end, both cases)

**Trigger:** the agent must choose a tool, e.g. "run the Rust tests fast/in parallel."

**Step 1 — once per session:** `bash <skill>/discover.sh` → the measured, real output:

```
PRESENT: cfr clippy nextest taplo audit deny tsc biome esbuild yq xmlstarlet xmllint jq pypdf
runtime: java 25.0.4 cargo 1.99.0 node v26.10.0 py 3.14
env: Arch Linux user=dev JAVA_HOME=/usr/lib/jvm/java-25-openjdk net=up
```

**Step 2 — selection:** for "fast Rust tests" the catalog prefers `cargo nextest`; the
probe confirms `nextest` is **present** (as `cargo-nextest`) → the agent runs
`cargo nextest run` directly.

**Step 3 — only when absent:** the fallback `nextest`→`cargo test` applies. No failed
`cargo nextest` invocation to then reason about.

**Step 4 — session:** remember the result; don't re-probe per tool. Re-run only on an
environment change (different container, user switches machines).

**Different environment** (e.g. a leaner container without the Rust extras):
- The same probe reports `nextest` **absent**, `cargo` present.
- The agent uses **`cargo test` immediately** (the fallback) — *before* trying any command.
- This is the win: the probe reports absence proactively instead of the agent walking a
  guess→error→reason loop.

**Invariant:** the agent *learns* availability from the probe and *usage* from the catalog —
two sources, never contradicting each other.

## Section D: Error handling and edge cases

Core principle: **the probe must never fail hard.** Each check is independent, and the probe
is **read-only and idempotent** (installs nothing, mutates nothing) — safe to run in any
state.

- **A single detect check errors** (e.g. `python3 -c "import pypdf"` with no `python3`):
  classified as **absent**, not a crash; the other checks continue.
- **Network check** always has a **timeout** (`timeout 3 curl …`) — never blocks.
  `env: net=down` is *information*, not an error.
- **The probe itself cannot run** (e.g. no `bash`): graceful degrade — the agent falls back
  to "informed blind" mode: apply the catalog's per-tool detect checks one by one. Slower
  but correct.
- **Environment changes mid-session:** workflow step 4 → re-run the probe. Don't speculate.
- **Stale catalog entry** (`jdeps`/`jshell`): shows up as **absent** in the probe; the
  catalog's usage knowledge stays **inert** until the tool is present. No error. *This* is
  the staleness fix — the catalog may list a tool even when absent, because it is a "what to
  use, if present" reference, not an "installed" claim.
- **Tool present but wrong version:** the probe reports runtime versions; incompatibility is
  a normal tooling decision — **out of scope** (YAGNI).
- **First build needs network:** catalog caveat + `env: net=up/down` → the agent warns
  proactively instead of only hitting the missing download.
- **None of the tools present:** `PRESENT` minimal → use only what's there, else the general
  rule → **ask before installing**.

## Section E: Testing / verification

No test framework (it's a docs/skill, like `java-guidelines`) — **mechanical checks + one
behavioral observation.**

**1. Probe self-test (reference container).** Run `discover.sh`, assert the expected set:
- `PRESENT` includes e.g. `cfr clippy nextest taplo audit deny … jq pypdf`;
- `jdeps`, `jshell` → **absent** (the proven stale entries — a positive test that the bug no
  longer surfaces);
- `env: … net=up`.
Repeatable and deterministic.

**2. Constrained-environment test.** Run the probe with a **restricted `PATH`** (e.g.
hide `cargo-nextest`) → it correctly reports `nextest` as absent. Verifies the type-aware
detection + fallback trigger in the real failure state, without provisioning a second
container.

**3. Skill-invocation test (the actual goal).** In a fresh session, pose a task that needs a
tool. Observe:
- the agent fires **one** probe per session — *not* N `command -v` guesses;
- the chosen tool is **actually present** (no failed invocation from an assumption);
- in a constrained env it uses the **fallback proactively**, not only after an error.

**Rollout** (per the `java-guidelines` pattern): add the `dev-tooling` row to
`README.md` → commit → pull in the live checkout `~/.config/respondami/skills/` so Respondami
discovers it in the next session.

**Success criterion (made checkable):** *one* probe call replaces *N* guess calls, at equal
or better hit rate.

## Out of scope (YAGNI)

- **No open-ended discovery** of arbitrary/unknown tools — the probe confirms the *known*
  set only.
- **No per-tool preferred→fallback pairs** beyond the real group branches (avoids catalog
  bloat and "fallback of the fallback").
- **No version-compatibility handling** beyond reporting runtime versions.
- **No fingerprint/skip optimization** to avoid probing in the known container — the probe
  is cheap (~60–70 tokens) and always-correct; a skip adds complexity and a staleness failure
  mode.
- **No state/cache file** for the probe result — "remember for the session" is a behavioral
  instruction, not persisted state.
- **No changes to the reference container** or its tool set — the skill reads, never installs.
