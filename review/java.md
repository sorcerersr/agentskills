# Java

Language file for the review skill. Load when `.java` files are in scope.

## Pass 0 — Project Understanding (Java)

1. Read `pom.xml` or `build.gradle` to understand dependencies, modules, and build structure.
2. Run `find . -name '*.java' -not -path '*/target/*' | xargs wc -l | sort -n` to inventory all Java files.
3. Examine package declarations and import statements to understand module dependencies.
4. Group files into layers:
   - **Core types & config** — domain types, config, constants, public API
   - **Infrastructure** — I/O, networking, persistence, provider abstractions
   - **Business logic** — services, core flows, orchestration
   - **UI / presentation** — controllers, views, rendering
   - **Utilities & tests** — helpers, test files
5. When package structure clearly indicates layers (e.g., `com.example.core`, `com.example.api`), follow that. Otherwise, use the generic layered grouping above.
6. Review in dependency order: core → infrastructure → business logic → presentation → utilities.

## Pass 1 — Language Checks

- Caught exceptions that are ignored or only logged
- Missing `@Override` on overridden methods
- Mutable static state
- Resource leaks: unclosed streams / connections (missing try-with-resources)

## Pass 2 — Language Checks

- Duplicate type definitions across packages
- Public API surface wider than necessary (leaking internal types)
- Deep class hierarchies that hide responsibilities

## Pass 3 — Dependency Audit (Java)

Audit `pom.xml` / `build.gradle` and the dependency tree. Check for:

- **Unused dependencies**: Declared dependencies not referenced in the source.
- **Duplicate functionality**: Multiple artifacts providing the same capability (e.g., two JSON libraries, two HTTP clients).
- **Conflicting versions**: The same artifact at different versions across modules.
- **Scope issues**: `test`-scoped dependencies used in main code.
- **Configuration issues**: Typos in artifact names, duplicate entries.

In changeset mode, audit only the changed manifest entries.

## Pass 4 — Guideline Compliance (Java)

- **Guidelines skill**: activate `java-guidelines`.
- **Tooling to check first**: google-java-format, Checkstyle (`checkstyle.xml`).
- **Review notes**:
  - `03_formatting.md` and `04_naming.md` apply to ALL Java tasks and are always loaded.
  - Javadoc requirements per `06_javadoc.md` — check where Javadoc is required.
  - Programming practices per `05_programming_practices.md` (`@Override`, caught exceptions, static member access, finalizers).
