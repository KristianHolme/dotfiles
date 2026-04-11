---
name: julia-performance-tips
description: Apply Julia performance optimization techniques when writing or optimizing Julia code. Use when optimizing functions, diagnosing performance issues, reviewing code for performance, or when the user asks about Julia performance, type stability, memory allocation, or code optimization.
---

# Julia Performance Tips

Essential performance optimization guidelines for Julia code. Reference: <https://docs.julialang.org/en/v1/manual/performance-tips/>

## Core Principles

### Functions and Globals

- **Put performance-critical code in functions** - code inside functions runs faster than top-level code
- **Avoid untyped global variables** - use `const` for globals, or pass as function arguments
- **Break functions into multiple definitions** - prefer `f(x::Vector) = ...` over `if isa(x, Vector) ... end`

### Type Stability

- **Write type-stable functions** - return consistent types: use `zero(x)` not `0`, `oneunit(x)` not `1`
- **Avoid changing variable types** - initialize with correct type: `x::Float64 = 1` not `x = 1` then `x /= ...`
- **Use function barriers** - separate type-unstable setup from type-stable computation

### Type Annotations

- **Avoid abstract type parameters** - prefer `Vector{Float64}` over `Vector{Real}`
- **Use parametric types for struct fields** - `struct MyType{T} a::T end` not `struct MyType a::AbstractFloat end`
- **Annotate values from untyped locations** - `x = a[1]::Int32` when working with `Vector{Any}`
- **Force specialization when needed** - `f(t::Type{T}) where T` not `f(t::Type)` for `Type`, `Function`, `Vararg`

### Memory Management

- **Pre-allocate outputs** - use in-place functions `f!(out, args...)` and pre-allocate `out`
- **Use views for slices** - `@views` or `view()` instead of `array[1:5, :]` when possible
- **Fuse vectorized operations** - `@. 3x^2 + 4x` fuses into single loop, `3x.^2 + 4x` creates temporaries
- **Unfuse when recomputing** - if broadcast recomputes constant values, pre-compute: `let s = sqrt.(d); x ./= s end`
- **Access arrays column-major** - inner loop should vary first index: `for col, row` not `for row, col`
- **Copy irregular views when beneficial** - copying non-contiguous views can speed up repeated operations

### Closures

- **Type-annotate captured variables** - `r::Int = r0` in closure scope
- **Use `let` blocks** - `f = let r = r; x -> x * r end` avoids boxing
- **Use `@__FUNCTION__` for recursive closures** - `(@__FUNCTION__)(n-1)` instead of `fib(n-1)`

### Advanced Types

- **Use `Val` for compile-time values** - `f(::Val{N}) where N` when dimension known at compile time
- **Avoid excessive type parameters** - only use values-as-parameters when processing homogeneous collections

## Performance Tools

- **`@time`** - measure time and allocations (ignore first run, it's compilation)
- **`@code_warntype`** - find type instabilities (red = non-concrete types)
- **`@allocated`** - measure memory allocations
- **`@code_typed`** - typed IR from inference (next step when `@code_warntype` is not enough detail)
- **`@code_llvm`** - LLVM IR for a call (inlining, other compiler optimizations)
- **`@code_native`** - native assembly for a call (e.g. verify vectorization)
- **BenchmarkTools.jl** - `@btime` / `@benchmark` for microbenchmarks with warmup, GC handling, and statistics; complements `@time`
- **Profiling** - use Profile.jl or ProfileView.jl for bottlenecks
- **JET.jl** - static analysis for performance issues
- **`--track-allocation=user`** - find allocation sources

## Performance Annotations

- **`@inbounds`** - disable bounds checking (use with caution)
- **`@fastmath`** - allow floating-point optimizations (may change results)
- **`@simd`** - promise independent loop iterations (experimental, use carefully)

## Miscellaneous

- **Avoid unnecessary arrays** - `x+y+z` not `sum([x,y,z])`
- **Use `abs2` for complex numbers** - `abs2(z)` not `abs(z)^2`
- **Use `div`, `fld`, `cld`** - not `trunc(x/y)`, `floor(x/y)`, `ceil(x/y)`
- **Fix deprecation warnings** - they add lookup overhead
- **Avoid string interpolation for I/O** - `println(file, a, " ", b)` not `println(file, "$a $b")`
- **Use `LazyString` for conditional strings** - `lazy"..."` for error paths
- **Set `OPENBLAS_NUM_THREADS=1`** when using `JULIA_NUM_THREADS>1` for multithreaded code

## Package Performance

- **Use PrecompileTools.jl** - reduce time-to-first-execution
- **Minimize dependencies** - use package extensions for optional features
- **Avoid heavy `__init__()`** - minimize compilation in initialization
- **Use `@time_imports`** - diagnose slow package loading
