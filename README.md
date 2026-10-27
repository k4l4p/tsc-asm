# tsc-asm

[![CI](https://github.com/k4l4p/tsc-asm/actions/workflows/ci.yml/badge.svg)](https://github.com/k4l4p/tsc-asm/actions/workflows/ci.yml)

A TypeScript type checker and type-erasing JavaScript emitter written from
scratch in x86-64 assembly, with tsc-compatible diagnostics.

Freestanding: no libc, no runtime, no dependencies, no heap. Built with GNU `as`
and `ld`, talks to Linux with raw syscalls.

**Status: experimental.** This is a deliberately small vertical slice of `tsc`,
not a replacement for it. Real projects with imports, classes, generics, unions,
or a `tsconfig.json` are out of scope. The supported language is defined below;
the short version is declarations, functions, `if`/`else`, `return`, calls,
operators, and five built-in types.

## Quick start

Requirements: x86-64 Linux, GNU binutils (`as`, `ld`), GNU Make, and Bash.
Node is only needed to run emitted JavaScript; `python3` is only needed for
`make bench`.

```sh
git clone https://github.com/k4l4p/tsc-asm.git
cd tsc-asm
make
./tsc-asm examples/hello.ts
node examples/hello.js
# total: 42
```

## Example

`examples/hello.ts`:

```ts
function add(a: number, b: number): number {
  return a + b;
}

let total: number = add(40, 2);

if (total > 0) {
  console.log("total:", total);
}
```

Type annotations are erased, `console.log` is left alone, and the result runs
under Node. Diagnostics use tsc's shape:

```
file.ts(1,5): error TS2322: Type 'string' is not assignable to type 'number'.
```

Exit code is `2` when any diagnostic is emitted, `0` otherwise.

## Why

A systems exercise: how much of a compiler can be built with statically sized
buffers, no allocation, and direct syscalls, while still producing tsc-compatible
diagnostics? The answer is the subset below — small, but fast on the inputs it
accepts. See [Performance](#performance).

## Build

```sh
make            # builds ./tsc-asm
make test       # 25 regression cases
make bench      # generated workload, tsc-asm vs tsc/tsrs if available
```

The binary is self-contained and static by construction (no dynamic loader).

## Usage

```
./tsc-asm [--noEmit] [--tokens] <file.ts>
```

| Flag | Effect |
| --- | --- |
| none | type-check and emit `<file>.js` (`.ts` suffix replaced, otherwise appended) |
| `--noEmit` | type-check only |
| `--tokens` | dump the token stream to stdout and do not emit |

* Diagnostics go to stdout as `file(line,col): error TSxxxx: message`, the same
  shape `tsc --pretty false` uses.
* Exit code `2` if any diagnostic was emitted, `0` otherwise. Emit happens even
  when diagnostics exist, matching `tsc`.
* `--tokens` and `--noEmit` may be combined (dump only).
* No `tsconfig.json`, no `--strict`, no project mode. The checker runs
  non-strict (`strictNullChecks` and `noImplicitAny` off), matching
  `tsc --strict false`.

## Supported TypeScript subset

Declarations and statements:

* `let`, `const`, `var` with optional `: type` and optional initializer
* `function name(a: type, b: type): type { ... }`
* `return` (bare or with expression), `if`/`else`, blocks, expression statements
* assignment to a plain identifier (`x = expr;`)
* `//` and `/* ... */` comments, automatic semicolon insertion
* `console.log(...)` as a built-in (arguments are not type-checked)

Types: `number`, `string`, `boolean`, `void`, `any`, function signatures.
Aliases, unions, generics, literals-as-types, `null`/`undefined` are not modeled.

Expressions: integer and string literals, `true`, `false`, identifiers, calls,
parentheses, unary `+ - !`, binary `+ - * / %`, `< > <= >=`, `=== !== == !=`,
`&& ||`.

Everything else is out of scope: floats, ternary, arrays, objects, classes,
interfaces, type aliases, enums, imports/exports, `for`/`while`/`switch`, arrow
functions, compound assignment, `++`/`--`, template literals, regex, member
access other than `console.log`, overloads, declaration files.

Function parameters require type annotations. A missing return annotation means
`any`.

## Type checking

* Assignability: identical types, or either side `any`. An internal error type
  suppresses cascading diagnostics, as tsc does.
* Non-strict rules: bare `return;` is allowed in any function, and returning a
  value from a `void` function is an error.
* `+`: `any` if either side is `any`, `string` if either is `string`, otherwise
  `number` for numbers; other combinations produce TS2365.
* Arithmetic `- * / %` requires numbers (TS2362/TS2363).
* Relational `< > <= >=` requires two numbers, two strings, or two booleans,
  else TS2365.
* Equality operators produce TS2367 when operand types have no overlap.
* `&&`/`||` produce `boolean` when both operands are boolean, otherwise `any`
  (approximation; see divergences).
* Calls: arity is checked before argument types. A wrong count produces TS2554
  (positioned at the callee when too few, at the first extra argument when too
  many). If arity is right, at most the first mismatched argument produces
  TS2345, matching tsc.
* Top-level function signatures are collected in a pre-scan, so calls may
  precede declarations. Top-level `let` declarations are visible only after
  their statement; an earlier function body does not see later top-level
  variables.
* `let`/`const` redeclaration in one scope gives TS2451 at both declarations.
  A variable/function name clash gives TS2300 at both. Duplicate function
  implementations in one scope give TS2393 at each declaration.
* `const x: number;` gives TS1155; assigning to a `const` gives TS2588.
* Calling a non-callable value gives TS2349 plus tsc's second indented line
  (`  Type 'Number' has no call signatures.`).

Diagnostics implemented: TS1002, TS1003, TS1005, TS1010, TS1108, TS1109, TS1110,
TS1127, TS1155, TS2300, TS2304, TS2322, TS2345, TS2349, TS2362, TS2363, TS2365,
TS2367, TS2391, TS2393, TS2451, TS2554, TS2588.

## Architecture

| File | Responsibility |
| --- | --- |
| `src/defs.inc` | token/type/symbol constants, syscall numbers, capacities |
| `src/data.s` | mutable globals and all fixed buffers (BSS) |
| `src/strings.s` | diagnostic fragments, type names, token display names |
| `src/util.s` | syscalls, message buffer, diagnostics, output emission |
| `src/lex.s` | tokenizer (keywords, literals, comments, multi-char operators) |
| `src/sym.s` | hashed symbol table, scope stack, parameter pool |
| `src/errors.s` | assignability and diagnostic constructors |
| `src/parse.s` | pre-scan, recursive-descent parser, type checker, emitter |
| `src/main.s` | argument parsing, file I/O, output naming |

Design:

* No AST. The parser returns type codes and emits JavaScript from source spans
  as it goes. Type annotations are skipped rather than emitted, which is what
  makes the output type-erased.
* Tokens are 24-byte records `{kind, offset, len, line, col, value}` in one
  flat array.
* Symbols are 52-byte records in one flat array with an FNV-1a hash index
  (65,536 buckets) and per-symbol links. Scope exit marks symbols dead instead
  of truncating the table, so hash chains stay valid while index order still
  encodes declaration order. Lookups are O(1) average rather than the O(n)
  backward scan a flat table would need.
* Emitted JS preserves the original token spellings (quotes, escapes, spacing
  inside initializer spans) and keeps `let`/`const`.
* No heap, no malloc: all storage is statically sized (see limits).

## Performance

Generated input: functions of three parameters called in order, plus one `let`
per function. Best of three runs, `--noEmit`, on the development machine
(node v23.3.0, TypeScript 5.9.3).

| Input | Functions | Tokens | tsc-asm | tsrs | tsc 5.9.3 |
| --- | --- | --- | --- | --- | --- |
| 629 KB | 4,000 | 216,008 | 21 ms | 89 ms | 763 ms |
| 1.58 MB | 10,000 | 540,008 | 26 ms | 105 ms | 1,059 ms |
| 4.06 MB | 25,000 | 1,350,008 | 54 ms | 153 ms | 1,818 ms |

Peak resident memory on the two larger inputs:

| Tool | 1.58 MB | 4.06 MB |
| --- | ---: | ---: |
| tsc-asm | 24 MB | 50 MB |
| tsrs | 153 MB | 210 MB |
| tsc 5.9.3 | 309 MB | 468 MB |

`tsc` spends roughly a second on process startup, so small-file ratios are not
meaningful. The symbol table used to be a linear backward scan, which made
large files quadratic; the hash index removed that.

This is not a like-for-like feature comparison. `tsrs` (0.20.0, TypeScript
7.1.0-beta) is a full TypeScript 7 compiler: it loads `lib.*.d.ts`, resolves the
whole language, and reports the same diagnostics as tsc on these inputs with
`--strict false`. `tsc-asm` accepts only the subset above. The numbers bound
the cost of that extra work on subset-compatible code, not conformance. On the
34-file `pi-observational-memory` project (strict mode, imports, Node types),
`tsrs -p .` takes 170 ms and `tsc -p .` 2,735 ms; tsc-asm cannot parse that
project at all.

```sh
make bench                       # 4,000 functions
BENCH_N=10000 make bench         # bigger workload
TSC=/path/to/tsc make bench      # explicit reference compiler
TSRS=/path/to/tsrs make bench    # compare against tsrs too
```

The bench script removes its generated file afterwards. If `tsrs` is on
`PATH`, it is picked up automatically and run with `--noEmit --strict false`
(`npm i -D tsrs`, then `TSRS=node_modules/.bin/tsrs make bench`). The native
binary from `@tsrs/linux-x64-gnu` was used above; the npm launcher adds roughly
10–20 ms of Node startup.

## Limits

| Resource | Capacity |
| --- | --- |
| source bytes | 4 MiB |
| tokens | 2,097,152 |
| symbols | 262,144 |
| parameter-pool entries | 262,144 |
| scope nesting | 1,024 |
| emitted bytes | 8 MiB |
| arguments checked per call | 64 |

Source-size, token, symbol, parameter-pool, and scope-depth overflow exit `1`
(the source-size path prints a message). Emitted output beyond 8 MiB is
truncated. Buffers are BSS and are paged in on demand.

## Tests

`tests/run.sh` compiles each `tests/cases/*.ts` and compares the diagnostics with
the matching `.expected` file. When a matching `.out` file exists, it also runs
the emitted JavaScript under `node` and compares stdout. The expected output of
the 25 cases was calibrated against TypeScript 5.9.3. Paths in diagnostics
include the directory prefix (`tests/cases/...`) because that is the argument
passed to the compiler.

## Deliberate divergences from tsc

* Syntax errors stop parsing of the affected construct; there is no tsc-style
  recovery and resynchronization. With any syntax error, semantic diagnostics
  that tsc would suppress may be reported here, and vice versa. The first syntax
  error usually matches tsc; later ones may not.
* Diagnostics are emitted in encounter order. tsc sorts by source position, so
  unusual interleavings (for example a duplicate function plus an error between
  the declarations) can differ in order.
* Emitted JavaScript keeps `let`/`const` and does not downlevel to ES5, add
  helpers, or produce source maps. Formatting is span-preserving, so it tends to
  match the source rather than tsc's printer.
* Logical `&&`/`||` use `any` when an operand is not boolean, so tsc's literal
  and union narrowing (and TS2872 "always truthy" on `if (1)`) is not modeled.
* `if` conditions are not type-checked.
* Unknown identifiers in type positions produce TS2304, but only in files
  without syntax errors, because parsing stops at the first syntax error.
* `console.log` is a special case. Other member expressions and `console` used
  as a value are unsupported.
* An unannotated function return type is `any`; tsc infers it from the body.
* Functions are not first-class values: calls are checked only when the callee
  is a declared function name. Assigning a function to a variable is emitted
  but the copy has no signature, so calls through it fail arity checking.
* Temporal-dead-zone use (`console.log(x); let x = 1;`) reports TS2304 instead
  of tsc's TS2448, and type inference is limited to literal/expression types
  (no flow narrowing, no literal types).
* Only decimal integer literals; there are no floats, hex/binary/octal, or
  numeric separators.
* `var` is parsed and emitted, but modeled as block-scoped: it is not hoisted
  out of blocks or functions (`if (true) { var x = 1; } x = 2;` reports TS2304),
  and duplicate `var` declarations are not checked (tsc reports TS2403 for
  incompatible types and TS2300 against a function).
* Only a single input file. No `tsconfig.json`, no `lib.d.ts`, no global types.

## Files

```
Makefile
README.md
LICENSE
src/*.s, src/defs.inc
examples/hello.ts
tests/run.sh, tests/bench.sh, tests/cases/*
.github/workflows/ci.yml
```

## Contributing

Issues and pull requests are welcome. Keep the constraints intact: freestanding
x86-64 Linux, no libc, no heap, GNU `as`/`ld`, and diagnostics that match the
reference `tsc` behavior for the supported subset. New language features should
come with a case under `tests/cases/`.

## License

MIT. See [LICENSE](LICENSE).

Diagnostic codes and message wording are modeled on TypeScript
([Apache-2.0](https://github.com/microsoft/TypeScript/blob/main/LICENSE.txt));
this repository contains no TypeScript source code. `tsrs` and `tsc` are
referenced only as benchmark baselines.

