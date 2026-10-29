# Parametric struct constructor checks (2l)

Read when a type in the inventory has type parameters.

For each type with type parameters, examine its constructor methods in the inventory. Read constructor method bodies (an exception to the inventory-only rule): signatures alone do not reveal coercion logic. Flag:

- **Inner constructor that constrains its value arguments.** Written `MyStruct{A,B}(a::A, b::B) where {A,B}` (arguments echoing the parameters) rather than `MyStruct{A,B}(a, b) where {A,B}`. The constrained form disables the conversion the field declarations + `new` would otherwise perform, so a call like `MyStruct{Float64}(1, 0)` fails with a `MethodError`. Constraints in the `where` that express *relationships among parameters* (e.g. `A<:AbstractArray{T,N}`) are correct and must stay — the flag is only for constraints on the argument *values*.
- **Custom constructors that duplicate the auto-generated ones.** by default Julia creates two constructors, an inner
constructor `MyStruct{A,B}(a,b) = new{...}(...)` and an outer constructor `MyStruct(a::A, b::B) = MyStruct{A,B}(a, b)`. Constructors that only duplicate this can be flagged for deletion.
- **A missing or broken constructor cascade.** `MyStruct(args...)`, `MyStruct{A}(args...)`, and `MyStruct{A,B}(args...)` should all reach the same coercion path, typically by delegating inwards. Flag call forms implemented as separate, divergent code paths instead of each delegating one step inward. Also flag when partially-parameterized forms are absent; an exception to this rule are trailing parameters that exist to confer inferrability but are not typically expected to be directly manipulated by users, e.g., `MyStruct{A,B}(a, b, c, d)` → `MyStruct{A,B,typeof(cA),typeof(dB)}(a, b, cA, dB)` might be fine if the `struct` declaration places restrictions on `C` and `D` that depend on `A` and `B`, and `cA` and `dB` have been `converted` to suitable form, e.g., `cA = convert(AbstractArray{A}, c)::AbstractArray{A}` if `C<:AbstractArray{A}`.
- **Argument validation or initialization that belongs in the inner constructor** Often the primary job of outer constructors is to determine type parameters (`promote_type`, `eltype`, `float`, …) and delegate inward. Only the inner constructor can prevent construction of broken `struct`s, initialize appropriate internal caches, etc.

The suggested change for any such finding should include a test that the reachable call forms produce equal results for the same inputs. Fixing these is normally non-breaking (a looser signature accepts a strict superset; cascade methods are additions) — place them in Tier 2 unless a specific change drops a previously-accepted call.

