---
name: review-api
description: Review a Julia package's public API for consistency with modern Julia and Base conventions (dims keywords, argument order, in-place pairs, flags, init, sorting, allocation, do-blocks, kwargs, naming, over-tight annotations, constructors). Produces a tiered report; does not change code. Use when the user asks for an API review of a Julia package.
disable-model-invocation: true
---

Review the Julia package in the current working directory for API convention issues: places where its API would surprise a user who learned Julia in the modern era (1.6+), compared with Base and the standard library. Assume the code runs; do not hunt bugs or deprecated syntax. Produce a tiered report and a short modernization-policy discussion; do not implement changes. The module name is in `Project.toml`.

---

## Phase 1 — Inventory the public API

Delegate the read to a subagent (a fast, cheap model is enough) so the full source stays out of the main
context. Give it [references/api-inventory.md](references/api-inventory.md) as its prompt and the
package path. If no subagent
is available, follow the same prompt inline, then continue from its output only.

It returns a structured inventory of all public method signatures. Work from that inventory — do not re-read the source — to run the convention checks below. Read single source lines only to confirm a specific finding.

---

## Phase 2 — Check each convention category

For each public item, run these checks. For each finding, record: the function name, file and line number, the current signature or pattern, the suggested change, and whether the change would be breaking.

### 2a. Dimension arguments

Does the function operate along a dimension of an array (or similar container)? If so, check whether the dimension is passed as:
- A trailing positional integer: `f(A, 2)` — **flag**: modern Julia passes dimension as `f(A; dims=2)`, following `sum`, `maximum`, `findmax`, etc.
- A positional `Val{d}()` argument: `f(A, Val(2))` — **flag**: this was a performance workaround that is usually no longer needed; prefer `dims` keyword with `dims::Union{Int,Tuple{Vararg{Int}}}`.

Check whether the function also supports `dims` as a `Tuple` for operating over multiple dimensions simultaneously (as `sum(A; dims=(1,3))` does). If it only accepts a scalar, flag it.

### 2b. Data-first argument ordering

In Julia, the convention is: data comes first, configuration/options come after (as positional or keyword args). Flag:
- Functions where a mode, type selector, or configuration value is the *first* positional argument and data is second.
- Functions where a callable (function argument) is not in the first position when the function is reduction/transform-like — exception: `map(f, A)` puts `f` first, which is also idiomatic when the function is primary. Use judgment: is the function more like `map` (callable is the point) or more like `sort` (the data is the point, `by=` is a modifier)?

### 2c. In-place / out-of-place pairing

For every function ending in `!` (mutating), check whether a non-mutating counterpart exists with the same base name. For every non-mutating function, check whether an in-place variant would be natural (i.e., the function produces an array-valued result of the same shape/type as an input). Flag asymmetric pairs.

Do not flag `!`-functions with no natural out-of-place form (like `push!`).

### 2d. Boolean and integer flags as positional arguments

Flag functions where a `Bool`, small `Int`, or `Symbol` positional argument is used purely as a configuration switch — something like `f(A, true)` or `f(A, :mode)`. Modern Julia convention is to use keyword arguments for configuration. Positional arguments should represent data, not behavior switches.

Exception: a `Symbol` that selects meaningfully different dispatch (so different that it acts like a different function) may be reasonable; flag it but note the nuance.

### 2e. Reduction `init` argument

For functions that reduce a collection to a scalar (or smaller array) and accept an initial value, check whether that initial value is passed positionally or as an `init` keyword. Modern Julia uses `init`: `reduce(op, A; init=0)`.

### 2f. Sorting and ordering

For functions that sort, rank, or compare elements, check for:
- Custom comparator as positional argument → should be `lt=` keyword
- Key extraction function as positional argument → should be `by=` keyword
- Reverse order as positional `Bool` → should be `rev=` keyword (defaulting to `false`)

### 2g. Output allocation conventions

For functions that return a new array, check:
- Is the output type/eltype hard-coded when it could be inferred from the input via `similar`?
- Is there a way for the caller to provide a pre-allocated output buffer? If not, and the function is likely to be called in a hot loop, flag the absence of an in-place variant (covered by 2c) and note the allocation concern.

### 2h. `do`-block compatibility

Functions whose first argument is a callable should be compatible with `do`-block syntax by putting the callable first. Flag functions where a callable argument exists but is not in the first position, making `do` blocks unusable.

### 2i. Keyword passthrough

Functions that wrap another function (from Base or another package) should generally accept and forward `kwargs...` rather than listing a fixed subset of the underlying function's keywords. Flag functions that explicitly list keywords from an underlying function without forwarding the rest, unless there is a good reason to restrict them.

### 2j. Internal naming consistency

Across the package's own API (not by comparison with Base), look for:
- Analogous operations that are named inconsistently (e.g., one uses `compute_`, another uses `make_`, another uses `build_` for structurally similar operations)
- Functions that differ in argument order for no apparent reason compared to closely related functions in the same package
- Inconsistent keyword argument names across related functions (e.g., `dims` in one function but `dim` in another, or `tol` vs `atol` for tolerance)

### 2k. Overly-restrictive type annotations

Argument types should generally be tight enough to control dispatch. Look for signatures that appear to be inappropriately narrow. For the special case of parametric struct constructors, see 2l.

### 2l. Parametric struct constructor design

For each type with type parameters, check its constructors (inner/outer cascade, coercion, validation). This is the one check that reads constructor bodies. Read [references/constructors.md](references/constructors.md) first. Findings are normally Tier 2.

### 2m. `one` vs `oneunit`

`one(T)` is the multiplicative identity and need not have type `T` (e.g. unitful quantities); `oneunit(T)` must have type `T`. Flag `one(T)` where a value of type `T` is required.

---

## Phase 3 — Compile the report

Group findings into three tiers:

**Tier 1 — Breaking changes** (changing the signature would break callers):
List each finding with: function, current signature, proposed signature, rationale by analogy to Base.

**Tier 2 — Non-breaking improvements** (can be introduced while keeping old signature via a compatibility shim or default):
List each finding with the same format.

**Tier 3 — Internal consistency** (naming and ordering issues within the package, no direct Base analogy):
List each finding.

Note clusters of related changes (e.g., "all dimension arguments across 5 functions") that should be handled together to avoid a partially-modernized API. Clusters may span tiers — a Tier 1 signature change and the Tier 2 deprecation shim that supports it are part of the same cluster, not separate ones.

Present the report to the user. **[pause for approval]** Wait for explicit confirmation of which tiers and specific items to address. Record items the user declines, with a one-line reason, so the result reflects considered choices.

### Interview

Ask the user for a short paragraph (or bullets) covering:

- **Modernization aggressiveness and breaking-change tolerance** — pre-1.0 (breaking changes cheap) vs. post-1.0 (each one expensive); preference for Tier 2 deprecation shims vs. clean breaks.
- **API surface preferences relative to Base** — how closely the package should mirror Base conventions when in tension with existing user code.

Keep the reply verbatim as "Stated values"; it is the tiebreaker for later decisions.

If the findings should be tracked on GitHub, offer to draft an issue (or a
comment on an existing one) and run `gh issue create` / `gh issue comment` only
after the user approves the exact text.

---

## Phase 4 — Next steps

This skill does not write a plan file or implement changes. Summarize the
approved findings, grouped into clusters that should land together, each with
its breaking flag and the user's stated values as tiebreakers. Offer to plan
the implementation with `agent-planning`, one cluster at a time. Apply
breaking changes only after the user has chosen a release strategy (a final
non-breaking release first, or batch into one breaking release).

<!-- Adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
