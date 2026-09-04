---
name: julia-code
description: >-
  Write and edit Julia code with Runic formatting, SciMLStyle, idiomatic style,
  and project conventions. Use whenever writing, editing, reviewing, or
  refactoring Julia (.jl/.jmd), or when the user mentions Julia, Runic, SciMLStyle,
  Float32 literals, or Julia packages.
paths: "**/*.{jl,jmd}"
---

# Julia code

Apply this skill for any Julia writing or editing. Read linked references only when needed.

## Non-negotiables

- **Idiomatic Julia**: multiple dispatch, type system; prefer performance-aware patterns.
- **Explicit `return`** in `function` / `macro` bodies (Runic).
- **Float32 literals**: `3.4f6` — never `3.4e6f0`.
- **Plotting**: Makie only (`makie-core` / `makie-dynamic` / `algebra-of-graphics` as appropriate).
- **Eval / REPL**: use `juliaclient` (see `juliaclient` skill).
- **Project.toml / Manifest.toml**: do not edit without user approval; prefer Pkg/MCP APIs (see `julia-project`).
- **No unsolicited files**: do not create example or test files unless asked; ask first if unsure.
- **Scope**: only what was asked; do not expand into drive-by refactors.

## Keyword arguments and NamedTuples

```julia
# no
func(pos1, pos2, kw1 = kw1, kw2 = kw2)
nt = (title = title, score = score)

# yes
func(pos1, pos2; kw1, kw2)
nt = (; title, score)
```

## Formatting and style (summary)

- **Runic**: 4-space indent; spaces around most operators/`=`; no spaces around `:`, `^`, `::`, unary `<:`/`>:`; `for x in xs`; block bodies with newlines; explicit `return`; trailing commas in multiline array/tuple literals; `# runic: off` / `# runic: on` for manual layout; `where {T}` braces.
- **SciMLStyle**: match existing file first; ~92-char soft limit; mutating names end with `!`; no type piracy; concrete parametric fields; generic interfaces.

Full detail when needed:

- [references/runic.md](references/runic.md)
- [references/sciml-style.md](references/sciml-style.md)

## Docs and introspection

Prefer Julia’s own tools (via `juliaclient`) before guessing APIs or scraping the web:

- REPL help: `?Foo` / `?Foo.bar` (or `@doc Foo`)
- Dispatch: `methods(f)`, `methodswith(T)`, `which(f, types)`
- Types/values: `typeof`, `eltype`, `fieldnames`, `propertynames`, `dump`, `names(Module)`
- Search: `apropos("keyword")`

## Analysis (optional)

`jetls` should be on `PATH` (`~/.julia/bin/jetls`). Use it when static/runtime-aware diagnostics would help (`jetls check …`). Run `jetls --help` (and `jetls <command> --help`) for usage.

## Related skills

| Need | Skill |
|------|--------|
| Run / eval Julia | `juliaclient` |
| `Project.toml`, JLD2 migrations | `julia-project` |
| Scripts / `_research` / examples | `julia-interactive-scripts` |
| Performance | `julia-performance-tips` |
| Profiling | `julia-profiling-agent` |
| Custom `show` | `custom-julia-show` |
| Plotting | `makie-core`, `makie-dynamic`, `algebra-of-graphics` |
| Library docs / upstream source | `github-cli` |

## Useful packages

Informational only — do not add a package just because it is listed. Details: [references/packages.md](references/packages.md).
