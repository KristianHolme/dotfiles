---
name: custom-julia-show
description: Write custom Julia Base.show methods for user-defined types. Use when implementing pretty printing, REPL display, MIME display, repr output, IOContext-aware display, or custom textual representations in Julia.
---

# Custom Julia `show`

Use this skill when writing or reviewing custom display methods for Julia types. Also apply the `julia-code` skill for style, Runic formatting, and general Julia practices.

References:
- <https://docs.julialang.org/en/v1/base/io-network/#Base.show-Tuple%7BIO,%20Any%7D>
- <https://docs.julialang.org/en/v1/base/io-network/#Base.show-Tuple%7BIO,%20Any,%20Any%7D>
- <https://docs.julialang.org/en/v1/manual/types/#man-custom-pretty-printing>

## Core Rules

- Extend `show` only for types you own. Do not commit type piracy by defining `Base.show` for someone else's type.
- Prefer `import Base: show` near the top of the module, then add methods as `show(...)`.
- Always write to `io`; never assume display goes to `stdout`.
- Use `print(io, ...)`, `show(io, ...)`, or `write(io, ...)` directly. Avoid building large intermediate strings just to print them.
- The 2-argument method `show(io::IO, x::T)` is the Julia-like representation used by `repr(x)` and by fallback display. When practical, make it valid Julia code that reconstructs the value.
- The 3-argument method `show(io::IO, ::MIME"text/plain", x::T)` is the richer human-readable representation used by the REPL and text displays.
- Do not overload `display` for custom object formatting. `display` selects a display backend; `show` writes a representation.

## Standard Pattern

For most user-defined types, define a compact 2-argument method first:

```julia
import Base: show

struct SamplePoint{T}
    x::T
    y::T
end

function show(io::IO, p::SamplePoint)
    print(io, "SamplePoint(")
    show(io, p.x)
    print(io, ", ")
    show(io, p.y)
    print(io, ")")
    return nothing
end
```

Add `text/plain` only when the REPL should show more context than the compact form:

```julia
function show(io::IO, ::MIME"text/plain", p::SamplePoint{T}) where {T}
    if get(io, :compact, false)::Bool
        show(io, p)
    else
        print(io, "SamplePoint{", T, "} with coordinates ")
        show(io, p)
    end
    return nothing
end
```

## `IOContext` Handling

Check `IOContext` keys in 3-argument `text/plain` methods and in container displays:

- `:compact`: print a single-line compact representation. Container elements are often displayed with `:compact => true`; compact output should not contain line breaks.
- `:limit`: truncate large containers or summaries when true.
- `:displaysize`: respect available `(rows, cols)` for text output when laying out multi-line displays.
- `:typeinfo`: avoid repeating type information already shown by an enclosing container.
- `:color`: emit ANSI styling only when true.

Pass context through when displaying nested values:

```julia
function show(io::IO, ::MIME"text/plain", xs::MyContainer)
    compact_io = IOContext(io, :compact => true)
    print(io, "MyContainer(")
    for (i, x) in enumerate(xs.values)
        i == 1 || print(io, ", ")
        show(compact_io, MIME"text/plain"(), x)
    end
    print(io, ")")
    return nothing
end
```

## MIME Display

Define additional MIME methods for rich frontends only when the representation is real and useful:

```julia
function show(io::IO, ::MIME"text/html", p::SamplePoint)
    print(io, "<code>SamplePoint</code>(")
    show(io, MIME"text/html"(), p.x)
    print(io, ", ")
    show(io, MIME"text/html"(), p.y)
    print(io, ")")
    return nothing
end
```

Use `MIME"text/plain"` and `MIME"text/html"` for literal MIME types. For dynamic MIME construction, use `MIME("text/plain")` or the parametric form documented by Julia.

## `print`, `summary`, and `repr`

- Define `print(io, x::T)` only when the plain, undecorated representation should differ from `show`. `print` falls back to `show`.
- Define `summary(io, x::T)` when a short description is needed for containers or headers.
- Use `repr(x)` to test the 2-argument `show` result.
- Use `repr("text/plain", x)` or `sprint(show, MIME"text/plain"(), x)` to test `text/plain`.
- Use `sprint(show, x; context = :compact => true)` or `repr("text/plain", x; context = :compact => true)` to test compact behavior.

## Edge Cases

- If the 2-argument representation uses infix operators and may appear inside Julia expressions, consider whether `Base.show_unquoted` is needed so expression printing preserves precedence.
- If rich display availability depends on the value, consider a custom `showable` method; otherwise Julia detects displayability from the `show` method.
- For binary MIME output such as `image/png`, write bytes to `io`; for textual MIME output, write text.

## Review Checklist

- The method extends `show` for an owned type.
- The 2-argument method is compact, single-line, and Julia-like when possible.
- The `text/plain` method is only added when human-readable display should differ.
- `:compact` is handled, and compact output has no line breaks.
- Nested values are displayed with `show`, not string interpolation.
- Tests or verification cover `repr(x)`, `repr("text/plain", x)`, and compact context when relevant.
