# TypeScript

Language file for the review skill. Load when `.ts`, `.tsx`, `.mts`, or `.cts` files are in scope.

## Pass 0 — Project Understanding (TypeScript)

1. Read `package.json` to understand dependencies, scripts, and entry points.
2. Read `tsconfig.json` (and any referenced project configs) for strictness settings and project structure.
3. Run `find . \( -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' \) -not -path '*/node_modules/*' | xargs wc -l | sort -n` to inventory all TypeScript files.
4. Examine import statements to understand module dependencies.
5. Group files into layers:
   - **Core types & config** — shared types, interfaces, config, constants
   - **Infrastructure** — I/O, networking, persistence, provider abstractions
   - **Business logic** — core flows, handlers, orchestration
   - **UI / presentation** — components, rendering, state management
   - **Utilities & tests** — helpers, test files
6. When directory structure clearly indicates layers (e.g., `src/core/`, `src/api/`), follow that. Otherwise, use the generic layered grouping above.
7. Review in dependency order: core → infrastructure → business logic → presentation → utilities.

## Pass 1 — Language Checks

- `@ts-ignore` / `@ts-expect-error` / `@ts-nocheck` suppressing real errors
- `any` leaking across module boundaries
- Unhandled promises, un-awaited async calls in fire-and-forget positions
- Unchecked `null` / `undefined` dereferences

## Pass 2 — Language Checks

- Duplicate type definitions that should be shared
- Barrel-file re-export sprawl that obscures provenance
- Public API surface wider than necessary (leaking internal types)

## Pass 3 — Dependency Audit (TypeScript)

Audit `package.json` and the dependency tree. Check for:

- **Unused dependencies**: Cross-reference each entry in `dependencies` against imports in the source. Flag deps with no imports.
- **Dev-dependency leakage**: `devDependencies` imported in production code (outside test files).
- **Duplicate functionality**: Multiple packages providing the same capability (e.g., two HTTP clients, two state libraries, two date libraries).
- **Undeclared imports**: Packages imported directly but not declared in `package.json` (phantom dependencies).
- **Configuration issues**: Typos in package names, duplicate entries, conflicting version requirements.

In changeset mode, audit only the changed manifest entries.

## Pass 4 — Guideline Compliance (TypeScript)

- **Guidelines skill**: activate `typescript-guidelines`.
- **Tooling to check first**: Prettier (`.prettierrc`), ESLint (`eslint.config.js` / `.eslintrc`), tsconfig.
- **Review notes**:
  - `@ts-ignore` and its variants are must-violations; High when they can mask a real bug.
  - The guide's policies file (`06_policies.md`) governs consistency with existing code — apply the consistency policy in the Pass 4 procedure.
  - `01_language_features.md` and `03_naming.md` apply to ALL TypeScript tasks and are always loaded.
