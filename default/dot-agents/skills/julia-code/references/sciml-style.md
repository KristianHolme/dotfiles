# SciMLStyle summary

Sources:

- <https://docs.sciml.ai/SciMLStyle/stable/>
- <https://github.com/SciML/SciMLStyle/blob/main/README.md>

Fetch those if more detail is needed.

## Quick workflow

- Match the existing file style first; avoid repo-wide reformatting.
- Apply key rules to new or edited code only.
- Do not mix style-only changes with behavior changes.

## Core principles

- Prefer generic, interface-based code over concrete assumptions.
- Favor readability, safety, and maintainability over micro-optimizations.
- Avoid mixing mutating and non-mutating styles in the same logic path.

## Formatting and layout

- 4-space indentation, no tabs.
- Keep lines within a 92-character limit.
- Avoid extra whitespace inside `()`, `[]`, `{}`.
- Surround most binary operators with single spaces.
- No spaces around `:`, `^`, or `//`.
- `for x in xs` (never `=` or `∈`) in loops and comprehensions.
- Short-form functions only when they fit on one line.
- Separate positional and keyword arguments with `;` in calls.

## Naming

- Public APIs: avoid Unicode identifiers.
- Functions/variables: lowercase; constants: uppercase; types: CamelCase.
- Abstract types begin with `Abstract`.
- Private/internal names use `__` prefix.

## Functions and APIs

- Mutating functions end with `!`.
- No type piracy (only extend what you own).
- Prefer instances over types as arguments.
- Keep functions focused on one principle.
- Expose internal choices as options where practical.

## Types and annotations

- Prefer concrete, parametric field types.
- Use general argument types; avoid overly narrow annotations.
- Keep unions small (two or three types).

## Interfaces and generic code

- Prefer broadcasting, iteration, indexing interfaces.
- Avoid hard-coded indexing when broadcast/iterators work.
- Use trait/interface packages where appropriate (SciMLBase, ArrayInterface, …).
- If mutation is required, check mutability and error clearly.

## Safety

- Avoid `eval`, unsafe ops, and non-public Base APIs.
- Avoid `@inbounds` unless paired with explicit safety checks.
- Avoid `ccall` unless necessary; use safe C types and `GC.@preserve`.
- Initialize memory explicitly.
- Validate user input early with domain-specific errors.

## Modules, imports, exports

- Imports at top; blank line between `using` and `import`.
- Do not shadow functions casually.
- Export only stable, documented API symbols.

## Docs and tests

- Documenter.jl and concise public docstrings.
- Tutorials before reference in docs.
- Tests across a broad range of numeric/array types.
- Follow the project’s test framework and CI.
