# Useful Julia packages

Informational only. Never add or use a package just because it appears here.

## Accessors.jl

Functional, zero-overhead updates of **immutable** data via updated copies.

### Primary macros

- `@set obj.path = value` — new copy with path updated
- `@reset obj.path = value` — rebind `obj` to `@set` result
- `@modify(f, obj.path)` — apply `f` at path
- `@optic _.path` — reusable lens

### Advanced optics

- `Elements()` — all items in a collection
- `Properties()` — all fields of a struct / NamedTuple
- `If(predicate)` — filter optics
- `Index(i)` / `Key(k)` — dynamic access

### Usage rules

1. Prefer for `struct`, `NamedTuple`, `StaticArrays`.
2. Compose with `|>` for deep or conditional updates.
3. Safe in hot loops (compile-time optimized).
4. No mutation of the original; always return the new value.
