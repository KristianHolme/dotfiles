# Runic.jl formatting

Source: <https://raw.githubusercontent.com/fredrikekre/Runic.jl/refs/heads/master/README.md>

## Toggle formatting

`# runic: off` / `# runic: on` on their own lines, paired, same syntax level. At top level, `# runic: off` can disable the rest of the file. Also accepts `#! format: off` / `#! format: on`.

## Line width

No automated wrapping. Break lines or refactor manually.

## Newlines in blocks

Block bodies (`if`, `for`, `while`, `function`, `struct`, …) start and end with a newline. Empty blocks like `struct A end` are allowed.

## Indentation

Four spaces. Block constructs increase indent by one until `end`. Multiline listlikes (tuples, calls, arrays) indent contents one level when already multiline.

Soft indent (does not nest) for multiline operator chains and similar.

## Explicit `return`

Add `return` on the last expression of `function` / `macro` bodies, except:

- After `for` / `while` (add `return` after the loop if needed).
- `if` / `try` / `let` / `begin`: only if no `return` already inside.
- Macro call as last expr: `return` in front of the call unless return is inside the macro.
- Short-form functions, `->`, `do` blocks: no forced `return`.
- Last call is `throw` / `error` (or contains those names): no added `return`.
- Generally skip inside macros except known-safe Base ones (`@inline`, `@generated`, …).

## Spaces around operators and assignment

Single space around infix ops, assignments, comparisons, `<:` / `>:` as binary. Includes `f(a = 1)` and keyword args in definitions.

No spaces around `:`, `^`, `::`, unary `<:` / `>:`.

## Spaces around keywords

Single space (e.g. `struct Foo`, `function foo(x::T) where {T}`).

## Multiline listlikes

If already multiline: leading and trailing newline; trailing commas for array/tuple literals; optional for calls.

## Spacing in listlikes

No space before `,`; one space after. Strip leading/trailing spaces inside.

## Trailing semicolons

Remove inside block bodies. Keep at top/module level when used for output suppression.

## Float literals

Digit before and after `.`; no leading zeros in integral/exponent; no trailing fractional zeros; `e` not `E`.

## Hex / oct literals

Pad to type width (`UInt8` → 2 hex digits, etc.).

## Colon expressions

Parenthesize operator calls inside `:` ranges: `(1 + 2):(3 * 4)`.

## `in` in loops

`for i in 1:2` — not `=` or `∈`. Do not replace `∈` outside loop contexts.

## `where` braces

Always `where {T}` (braces around the RHS).

## Whitespace misc

Strip trailing spaces (except where it would change multiline strings). Tabs → spaces. At most two consecutive blank lines. No leading file blank lines; at most one trailing newline.
