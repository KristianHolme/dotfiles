---
name: julia-code
description: ALWAYS REQUIRED when writing julia code. Contains guidelines best practices and style.
---

# Julia code

## Useful packages

Te following packages might be useful when writing julia code. Always judge
wether or not to use one.
Never use a package just because it is mentioned here, this is for informational
purpose, but these can be quite useful.

### Accessors.jl

#### Core Purpose

Provides a functional, zero-overhead interface for "modifying" **immutable**
data structures by creating updated copies. It eliminates the boilerplate of
nested reconstructions.

#### Primary Macros

- **`@set obj.path = value`**: Returns a new copy of `obj` with the
  specified field updated.
- **`@reset obj.path = value`**: In-place syntax sugar; rebinds `obj` to
  the result of `@set`.
- **`@modify(f, obj.path)`**: Applies function `f` to the value at `path` and
  returns the new object.
- **`@optic _.path`**: Creates a first-class, reusable "lens" object
  representing a path.

#### Advanced Optics

- **`Elements()`**: Accesses all items in a collection (e.g.,
  `@set (1, 2, 3) |> Elements() = 0`).
- **`Properties()`**: Accesses all fields of a struct or NamedTuple.
- **`If(predicate)`**: Filters optics (e.g.,
  `@modify(x -> x+1, obj |> Elements() |> If(isodd))`).
- **`Index(i)` / `Key(k)`**: Dynamic access into arrays or dictionaries.

#### Usage Rules

1. **Immutability First**: Use when working with `struct`, `NamedTuple`, or `StaticArrays`.
2. **Composition**: Use the pipe operator `|>` to chain optics for deep or
   conditional updates.
3. **Performance**: Safe for inner loops; generates optimized code at
   compile-time equivalent to manual construction.
4. **No Side Effects**: Standard functions don't mutate the original input;
   they always return the transformed version.

## Style and format

Follow these guidelines when writing julia code.

### Keyword arguments

no: `func(pos1, po2, kw1 = kw1, kw2=kw2)`
yes: `func(pos1, pos2; kw1, kw2)`

Use this syntax also for namedtuples:
no: `nt = (title = title, score = score)`
yes: `nt = (;title, score)`

### Follow Runic.jl Formatting

Below is a summary of the format. If more details are needed, see <https://raw.githubusercontent.com/fredrikekre/Runic.jl/refs/heads/master/README.md>.

Runic Formatting Specification Summary

#### General Syntax & Spacing

Indentation: Consistently 4 spaces. Tabs are auto-converted to spaces.

Line Width: No automated wrapping; Runic assumes manual line breaks or
refactoring for long lines.

Vertical Space: Maximum of two consecutive empty lines allowed. Leading/trailing
file whitespace is trimmed to one newline.

Trailing Whitespace: All trailing spaces in code and comments are removed
(except within multiline strings).

#### Operators & Keywords

Binary Operators: Single space around infix operators (+, -, \*),
assignments (=, +=), and comparisons (<, >:).

Note: This includes spaces around = in keyword arguments (e.g., f(a = 1)).

Exceptions (No Spaces): No spaces around :, ^, ::, or unary <: and >:.

Keywords: Single space around keywords (e.g., struct Foo, where {T}).

Loop Syntax: Always uses in instead of = or ∈ in for loops.

#### Blocks & Control Flow

Newlines: Block bodies (if, for, function, etc.) must start and end with
a newline, unless the block is empty.

Explicit Return: Forced return on the last expression of functions/macros,
with logic to skip throw calls, do blocks, and short-form functions.

Semicolons: Trailing semicolons are removed inside blocks but preserved
at the top/module level for REPL suppression.

#### Collections & Lists

Multiline Lists: Tuples, calls, and arrays spanning multiple lines get
leading/trailing newlines and 4-space indentation.

Commas: No space before, one space after. Trailing commas are enforced for
multiline array/tuple literals but optional for function calls.

Parentheses: Added around operator calls within colon expressions
(e.g., (1+2):3) to clarify precedence.

#### Literals

Floats: Normalized to have a digit before and after the decimal
(e.g., 0.1, 1.0), no leading/trailing zeros, and lowercase e for exponents.

Hex/Octal: Padded to match type widths (e.g., 0x01 for UInt8, 0x00012345 for UInt32).

#### Configuration & Overrides

Toggling: Use # runic: off and # runic: on to wrap code that should remain
manually formatted. Runic also respects #! format: off/on for JuliaFormatter compatibility.

Braces: Right-hand side of `where` expressions must always be wrapped in braces {}.

### Use SciMLStyle

Apply the SciML Style Guide for Julia. Source references:

- <https://docs.sciml.ai/SciMLStyle/stable/>
- <https://github.com/SciML/SciMLStyle/blob/main/README.md>
  Fetch these documents if more details are needed. Below is a summary.

#### Quick Workflow

- Match the existing file style first; avoid repo-wide reformatting.
- Apply the key SciMLStyle rules to any new or edited code.
- Prefer minimal, focused changes; do not mix style-only changes with behavior changes.

#### Core Principles

- Prefer generic, interface-based code over concrete assumptions.
- Favor readability, safety, and maintainability over micro-optimizations.
- Avoid mixing mutating and non-mutating styles in the same logic path.

#### Formatting and Layout

- 4-space indentation, no tabs.
- Keep lines within a 92-character limit.
- Avoid extra whitespace inside `()`, `[]`, `{}`.
- Surround most binary operators with single spaces.
- Do not add spaces around `:`, `^`, or `//` (range, exponent, rational).
- Use `for x in xs` (never `=` or `∈`) in loops and comprehensions.
- Use short-form function definitions only when they fit on one line.
- Separate positional and keyword arguments with `;` in calls.

#### Naming Rules

- Public APIs should avoid Unicode identifiers.
- Functions/variables: lowercase; constants: uppercase; types: CamelCase.
- Abstract types begin with `Abstract`.
- Private/internal names use `__` prefix.

#### Functions and APIs

- Mutating functions must end with `!`.
- Avoid type piracy (only extend functions/types you own).
- Prefer instances over types as arguments (for extensibility and specialization).
- Keep functions focused on one underlying principle.
- Expose internal choices as options where practical.

#### Types and Annotations

- Prefer concrete, parametric field types over abstract fields.
- Use general argument types; avoid overly narrow annotations.
- Keep unions small (two or three types) and avoid elaborate union chains.

#### Interfaces and Generic Code

- Prefer generic interfaces: broadcasting, iteration, indexing, etc.
- Avoid hard-coded indexing when a broadcast or iterator works.
- Use trait/interface packages where appropriate (e.g., SciMLBase, ArrayInterface).
- If mutation is required, check mutability and provide contextual errors.

#### Safety and Robustness

- Avoid `eval`, unsafe operations, and non-public Base APIs.
- Avoid `@inbounds`; if used, add explicit safety checks.
- Avoid `ccall` unless necessary; use safe C types and `GC.@preserve`.
- Initialize memory explicitly; avoid uninitialized allocations unless fully filled.
- Validate user input early and use domain-specific error messages.

#### Modules, Imports, Exports

- Place imports at the top; separate `using` and `import` with a blank line.
- Do not shadow functions; use distinct names or extend intentionally.
- Export only stable, documented API symbols.

#### Distributed

- `@everywhere` must appear at true top level, not inside a `function`. It expands to a `toplevel` expression; wrapping `@everywhere function foo()` in a helper yields `syntax: "toplevel" expression not at top level`.
- `addprocs` first, then `@everywhere using Foo` / method definitions in a usage section of a script (not a `load_worker_code()` wrapper).

#### Documentation and Tests

- Use Documenter.jl and concise docstrings for public APIs.
- Keep tutorials before reference materials in docs.
- Ensure tests cover a broad range of numeric and array types.
- Follow the project’s test framework and CI conventions.
