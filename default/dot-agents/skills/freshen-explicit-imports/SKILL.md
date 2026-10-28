---
name: freshen-explicit-imports
description: Make a Julia package use explicit imports with ExplicitImports.jl — analyze implicit, stale, and non-public imports, fix them, and add a regression test. Use when the user asks for explicit imports, ExplicitImports.jl, or cleaning up `using` statements in a package.
disable-model-invocation: true
---

Adding a dependency changes `Project.toml`: confirm with the user first (see
`julia-project`). Use plain `julia` for `Pkg` operations and `juliaclient` for
analysis and test runs.

## 1. Add ExplicitImports.jl as a test dependency

Check how test dependencies are currently specified in this project:

- **If `test/Project.toml` exists**, add ExplicitImports via:
  ```
  julia --project=test -e 'using Pkg; Pkg.add("ExplicitImports")'
  ```
  and update the `[compat]` section of `test/Project.toml`.

- **If the root `Project.toml` uses `[extras]`/`[targets]`**, check the Julia compat lower bound:
  - **Julia 1.11+**: `julia --project -e 'using Pkg; Pkg.add("ExplicitImports"; target=:extras)'`
  - **Julia 1.10**: `julia --project -e 'using Pkg; Pkg.add("ExplicitImports")'`, then manually move the entry from `[deps]` to `[extras]` and add `"ExplicitImports"` to the `test` list under `[targets]`.

  In either case, add a `[compat]` bound for ExplicitImports at the minor version `Pkg.add` just installed (`ExplicitImports v1.15.0` → `"1.15"`). Do **not** use a looser bound like `"1"`: Step 4 uses `test_explicit_imports`, which exists only from v1.15, so an older version breaks the suite with `UndefVarError`. A tight bound is harmless for a test-only dependency.

  `juliaup` channels: `julia +release --project ...` (current release), `julia +lts --project ...`.

## 2. Run ExplicitImports analysis

`<PackageModule>` below is the name of the package defined in this repository.

Run the analysis on the **current Julia release** (1.11+) with `juliaclient --project` if the default channel is 1.11+, otherwise `julia +release --project`:

```julia
using TestEnv
TestEnv.activate()
using <PackageModule>, ExplicitImports
print_explicit_imports(<PackageModule>; report_non_public=true)
test_explicit_imports(<PackageModule>)
```

`print_explicit_imports` is a readable summary of implicit and non-public *imports*. `test_explicit_imports` is the regression guard Step 4 installs; it runs seven checks, several of which the summary does not surface (e.g. non-public *qualified accesses* such as `Base.Meta.parse`). Treat any failing check as a problem to fix in Step 3; do not rely on the summary alone.

**Julia-version caveat.** The two public-ness checks (`all_explicit_imports_are_public`, `all_qualified_accesses_are_public`) use `Base.ispublic` on 1.11+ but `Base.isexported` before, so on pre-1.11 they false-positive on `public`-but-unexported bindings. Do not analyse on pre-1.11, and gate those two checks in the installed guard (Step 4). The other five are version-robust.

For a quick overview without the test environment, the CLI also works
(`julia -m ExplicitImports <path>`, or the `explicit-imports-jl` wrapper if
installed: `--check`, `--checklist all,<check>,exclude_<check>`).

## 3. Report and fix

Summarize the results for the user. Use discretion: some reported violations
are acceptable. Differentiate `using` from `import`, and follow the SciMLStyle
module conventions (`julia-code/references/sciml-style.md`). Propose fixes for any detected problems (e.g., reliance on non-public API, implicit imports that should be made explicit). Wait for user approval before making changes.

Any code change must remain parseable on every supported Julia version. Notably, the `public` keyword is a syntax error before Julia 1.11, so declare public symbols with `@static if VERSION >= v"1.11"; eval(Expr(:public, :sym, ...)); end` rather than a literal `public` statement or `eval(Meta.parse("public ..."))` — `Expr(:public, ...)` builds the same AST using only public Base API, which the qualified-access check accepts.

## 4. Add to test suite and verify

Once issues are resolved, add `test_explicit_imports(<PackageModule>)` to the test suite to prevent regressions. Place it in its own `@testset "ExplicitImports"` block; if the suite already has a quality-checks testset (e.g. for Aqua), add it as a sibling alongside.

Check the `[compat] julia` lower bound in `Project.toml`. **If it is below 1.11**, gate the two public-ness checks by version so they run only where they are accurate (see the caveat in Step 2) — the other five checks still run on every version:

```julia
@testset "ExplicitImports" begin
    test_explicit_imports(<PackageModule>;
                          all_explicit_imports_are_public   = VERSION >= v"1.11",
                          all_qualified_accesses_are_public = VERSION >= v"1.11")
end
```

If the lower bound is already 1.11+, a plain `test_explicit_imports(<PackageModule>)` is fine.

Then run the full test suite and confirm it passes — on the current release, and, if the package supports it, on the lowest supported Julia version. With the gating above, both should be green. Do not finish this step with a red suite: if `test_explicit_imports` fails, return to Step 3.

<!-- Adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
