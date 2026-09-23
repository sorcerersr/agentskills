# Source File Structure

Files consist of the following, **in order**:

1. Copyright information, if present

2. JSDoc with `@fileoverview`, if present

3. Imports, if present

4. The file’s implementation

**Exactly one blank line** separates each section that is present.

## Copyright information

If license or copyright information is necessary in a file, add it in a JSDoc at the top of the file.

## `@fileoverview` JSDoc

A file may have a top-level `@fileoverview` JSDoc. If present, it may provide a description of the file's content, its uses, or information about its dependencies. Wrapped lines are not indented.

Example:

**Good:**
```ts
/**
 * @fileoverview Description of file. Lorem ipsum dolor sit amet, consectetur
 * adipiscing elit, sed do eiusmod tempor incididunt.
 */
```

## Imports

There are four variants of import statements in ES6 and TypeScript:

| Import type | Example | Use for |
| --- | --- | --- |
| module[module_import] | `import * as foo from '...';` | TypeScript imports |
| named[destructuring_import] | `import {SomeThing} from '...';` | TypeScript imports |
| default | `import SomeThing from '...';` | Only for other external code that requires them |
| side-effect | `import '...';` | Only to import libraries for their side-effects on load (such as custom elements) |

**Good:**
```ts
// Good: choose between two options as appropriate (see below).
import * as ng from '@angular/core';
import {Foo} from './foo';

// Only when needed: default imports.
import Button from 'Button';

// Sometimes needed to import libraries for their side effects:
import 'jasmine';
import '@polymer/paper-button';
```

### Import paths

TypeScript code *must* use paths to import other TypeScript code. Paths *may* be relative, i.e. starting with `.` or `..`, or rooted at the base directory, e.g. `root/path/to/file`.

Code *should* use relative imports (`./foo`) rather than absolute imports `path/to/foo` when referring to files within the same (logical) project as this allows to move the project around without introducing changes in these imports.

Consider limiting the number of parent steps (`../../../`) as those can make module and path structures hard to understand.

**Good:**
```ts
import {Symbol1} from 'path/from/root';
import {Symbol2} from '../parent/file';
import {Symbol3} from './sibling';
```

### Namespace versus named imports

Both namespace and named imports can be used.

Prefer named imports for symbols used frequently in a file or for symbols that have clear names, for example Jasmine's `describe` and `it`. Named imports can be aliased to clearer names as needed with `as`.

Prefer namespace imports when using many different symbols from large APIs. A namespace import, despite using the `*` character, is not comparable to a “wildcard” import as seen in other languages. Instead, namespace imports give a name to all the exports of a module, and each exported symbol from the module becomes a property on the module name. Namespace imports can aid readability for exported symbols that have common names like `Model` or `Controller` without the need to declare aliases.

**Bad:**
```ts
// Bad: overlong import statement of needlessly namespaced names.
import {Item as TableviewItem, Header as TableviewHeader, Row as TableviewRow,
  Model as TableviewModel, Renderer as TableviewRenderer} from './tableview';

let item: TableviewItem|undefined;
```

**Good:**
```ts
// Better: use the module for namespacing.
import * as tableview from './tableview';

let item: tableview.Item|undefined;
```

**Bad:**
```ts
import * as testing from './testing';

// Bad: The module name does not improve readability.
testing.describe('foo', () => {
  testing.it('bar', () => {
    testing.expect(null).toBeNull();
    testing.expect(undefined).toBeUndefined();
  });
});
```

**Good:**
```ts
// Better: give local names for these common functions.
import {describe, it, expect} from './testing';

describe('foo', () => {
  it('bar', () => {
    expect(null).toBeNull();
    expect(undefined).toBeUndefined();
  });
});
```

#### Special case: Apps JSPB protos

Apps JSPB protos must use named imports, even when it leads to long import lines.

This rule exists to aid in build performance and dead code elimination since often `.proto` files contain many `message`s that are not all needed together. By leveraging destructured imports the build system can create finer grained dependencies on Apps JSPB messages while preserving the ergonomics of path based imports.

**Good:**
```ts
// Good: import the exact set of symbols you need from the proto file.
import {Foo, Bar} from './foo.proto';

function copyFooBar(foo: Foo, bar: Bar) {...}
```

### Renaming imports

Code *should* fix name collisions by using a namespace import or renaming the exports themselves. Code *may* rename imports (`import {SomeThing as SomeOtherThing}`) if needed.

Three examples where renaming can be helpful:

1. If it's necessary to avoid collisions with other imported symbols.

2. If the imported symbol name is generated.

3. If importing symbols whose names are unclear by themselves, renaming can improve code clarity. For example, when using RxJS the `from` function might be more readable when renamed to `observableFrom`.

## Exports

Use named exports in all code:

**Good:**
```ts
// Use named exports:
export class Foo { ... }
```

Do not use default exports. This ensures that all imports follow a uniform pattern.

**Bad:**
```ts
// Do not use default exports:
export default class Foo { ... } // BAD!
```

**Why?**

Default exports provide no canonical name, which makes central maintenance difficult with relatively little benefit to code owners, including potentially decreased readability:

**Bad:**
```ts
import Foo from './bar';  // Legal.
import Bar from './bar';  // Also legal.
```

Named exports have the benefit of erroring when import statements try to import something that hasn't been declared. In `foo.ts`:

**Bad:**
```ts
const foo = 'blah';
export default foo;
```

And in `bar.ts`:

**Bad:**
```ts
import {fizz} from './foo';
```

Results in `error TS2614: Module '"./foo"' has no exported member 'fizz'.` While `bar.ts`:

**Bad:**
```ts
import fizz from './foo';
```

Results in `fizz === foo`, which is probably unexpected and difficult to debug.

Additionally, default exports encourage people to put everything into one big object to namespace it all together:

**Bad:**
```ts
export default class Foo {
  static SOME_CONSTANT = ...
  static someHelpfulFunction() { ... }
  ...
}
```

With the above pattern, we have file scope, which can be used as a namespace. We also have a perhaps needless second scope (the class `Foo`) that can be ambiguously used as both a type and a value in other files.

Instead, prefer use of file scope for namespacing, as well as named exports:

**Good:**
```ts
export const SOME_CONSTANT = ...
export function someHelpfulFunction()
export class Foo {
  // only class stuff here
}
```

### Export visibility

TypeScript does not support restricting the visibility for exported symbols. Only export symbols that are used outside of the module. Generally minimize the exported API surface of modules.

### Mutable exports

Regardless of technical support, mutable exports can create hard to understand and debug code, in particular with re-exports across multiple modules. One way to paraphrase this style point is that `export let` is not allowed.

**Bad:**
```ts
export let foo = 3;
// In pure ES6, foo is mutable and importers will observe the value change after a second.
// In TS, if foo is re-exported by a second file, importers will not see the value change.
window.setTimeout(() => {
  foo = 4;
}, 1000 /* ms */);
```

If one needs to support externally accessible and mutable bindings, they *should* instead use explicit getter functions.

**Good:**
```ts
let foo = 3;
window.setTimeout(() => {
  foo = 4;
}, 1000 /* ms */);
// Use an explicit getter to access the mutable export.
export function getFoo() { return foo; };
```

For the common pattern of conditionally exporting either of two values, first do the conditional check, then the export. Make sure that all exports are final after the module's body has executed.

**Good:**
```ts
function pickApi() {
  if (useOtherApi()) return OtherApi;
  return RegularApi;
}
export const SomeApi = pickApi();
```

### Container classes

Do not create container classes with static methods or properties for the sake of namespacing.

**Bad:**
```ts
export class Container {
  static FOO = 1;
  static bar() { return 1; }
}
```

Instead, export individual constants and functions:

**Good:**
```ts
export const FOO = 1;
export function bar() { return 1; }
```

## Import and export type

### Import type

You may use `import type {...}` when you use the imported symbol only as a type. Use regular imports for values:

**Good:**
```ts
import type {Foo} from './foo';
import {Bar} from './foo';

import {type Foo, Bar} from './foo';
```

**Why?**

The TypeScript compiler automatically handles the distinction and does not insert runtime loads for type references. So why annotate type imports?

The TypeScript compiler can run in 2 modes:

- In development mode, we typically want quick iteration loops. The compiler transpiles to JavaScript without full type information. This is much faster, but requires `import type` in certain cases.

- In production mode, we want correctness. The compiler type checks everything and ensures `import type` is used correctly.

Note: If you need to force a runtime load for side effects, use `import '...';`. See

### Export type

Use `export type` when re-exporting a type, e.g.:

**Good:**
```ts
export type {AnInterface} from './foo';
```

**Why?**

`export type` is useful to allow type re-exports in file-by-file transpilation. See [`isolatedModules` docs](https://www.typescriptlang.org/tsconfig#exports-of-non-value-identifiers).

`export type` might also seem useful to avoid ever exporting a value symbol for an API. However it does not give guarantees, either: downstream code might still import an API through a different path. A better way to split & guarantee type vs value usages of an API is to actually split the symbols into e.g. `UserService` and `AjaxUserService`. This is less error prone and also better communicates intent.

### Use modules not namespaces

TypeScript supports two methods to organize code: *namespaces* and *modules*, but namespaces are disallowed. That is, your code *must* refer to code in other files using imports and exports of the form `import {foo} from 'bar';`

Your code *must not* use the `namespace Foo { ... }` construct. `namespace`s *may* only be used when required to interface with external, third party code. To semantically namespace your code, use separate files.

Code *must not* use `require` (as in `import x = require('...');`) for imports. Use ES6 module syntax.

**Bad:**
```ts
// Bad: do not use namespaces:
namespace Rocket {
  function launch() { ... }
}

// Bad: do not use <reference>
/// <reference path="..."/>

// Bad: do not use require()
import x = require('mydep');
```

> NB: TypeScript `namespace`s used to be called internal modules and used to use the `module` keyword in the form `module Foo { ... }`. Don't use that either. Always use ES6 imports.

## File encoding: UTF-8

Source files are encoded in **UTF-8**.

### Whitespace characters

Aside from the line terminator sequence, the ASCII horizontal space character (0x20) is the only whitespace character that appears anywhere in a source file. This implies that all other whitespace characters in string literals are escaped.

### Special escape sequences

For any character that has a special escape sequence (`\'`, `\"`, `\\`, `\b`, `\f`, `\n`, `\r`, `\t`, `\v`), that sequence is used rather than the corresponding numeric escape (e.g `\x0a`, `\u000a`, or `\u{a}`). Legacy octal escapes are never used.

### Non-ASCII characters

For the remaining non-ASCII characters, use the actual Unicode character (e.g. `∞`). For non-printable characters, the equivalent hex or Unicode escapes (e.g. `\u221e`) can be used along with an explanatory comment.

**Good:**
```ts
// Perfectly clear, even without a comment.
const units = 'μs';

// Use escapes for non-printable characters.
const output = '\ufeff' + content;  // byte order mark
```

**Bad:**
```ts
// Hard to read and prone to mistakes, even with the comment.
const units = '\u03bcs'; // Greek letter mu, 's'

// The reader has no idea what this is.
const output = '\ufeff' + content;
```

## Footnotes

1. Namespace imports are often called 'module imports'

2. named imports are sometimes called 'destructuring imports' because they use similar syntax to destructuring assignments.
