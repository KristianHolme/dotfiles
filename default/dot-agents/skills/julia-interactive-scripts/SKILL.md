---
name: julia-interactive-scripts
description: Write Julia scripts for interactive REPL work — sectioned, top-level flow, display-before-save. Use when creating or editing files in scripts/, _research/, or examples/, or when the user asks for analysis, plotting, validation, or one-off experiment scripts (not library code in src/). Covers both DrWatson projects and plain using/Pkg.activate demos without DrWatson.
---

# Julia Interactive Scripts

Scripts are for **interactive REPL work** (include / run section-by-section), not reusable library code. Prefer flat, sectioned scripts over wrapping logic in functions.

## Section markers

Use `##` to split setup, plot, save, etc. so blocks can be re-run independently in the IDE/REPL.

Imports and activation stay **above** the first `##` — load packages in one block, then sections start.

### Script layout

Keep a consistent section order:

1. **Imports** — `using`, `@quickactivate`, etc. (no `##`)
2. **Utilities** — helper functions reused within the file (first `##`)
3. **Constants** — truly immutable values only (second `##`, rare; skip when nothing qualifies)
4. **Usage** — setup, compute, plot, save, etc. (remaining `##` sections)

Put utility functions in section 2, not scattered through usage sections. Put `const` values in section 3 only when they are obviously never meant to change — not mixed into imports or buried after setup code.

Numbered sections (`## 1) …`, `## 2.5) …`) are fine in `examples/` when the script is a tutorial with multiple demos; use them for usage sections (4+), not for utilities or constants.

## Top-level flow

Compute at script scope in usage sections. Use plain assignments for values that feed into later computation (`ny = 64`, `params = …`, `y_correct = …`).

Avoid helper functions unless the logic is genuinely reused within the same file. When functions are needed, define them in the utilities section (section 2) and follow [julia-code](../julia-code/SKILL.md) (explicit `return`, Runic formatting). Put tunable defaults in keyword arguments (`function plot_result(data; color = :steelblue, linewidth = 2)`) so callers can override without editing the function body.

**Call-site knobs go inline.** When overriding helper kwargs (figure size, colors, spacing, markersize, etc.), pass them directly in the call — do **not** declare locals and then forward them:

```julia
# preferred
fig = plot_field(u; figsize = (800, 600), colormap = :viridis)

# avoid — pointless assign-then-pass
figsize = (800, 600)
colormap = :viridis
fig = plot_field(u; figsize, colormap)
```

Reserve `const` (section 3) for values that are clearly and permanently fixed — e.g. a physical dimension baked into the model, a file extension that the script always uses, a literal that would be nonsensical to change. Do **not** use `const` for visual or experimental knobs the user might adjust between REPL runs.

## Brief context at top

A short comment block explaining what the script does is fine (before the imports). Don't turn the whole script into a small API.

## Interactive first

Call `display(fig)` (or equivalent) before saving so the figure can be inspected live.

## Save in its own section

When saving, use a separate `##` block at the bottom — never hide save logic inside a wrapper function.

**DrWatson projects** (`scripts/`, `_research/`): use `plotsdir(...)` / `datadir(...)` and `wsave(path, fig)` (or `safesave`).

**Without DrWatson** (`examples/`, standalone demos): saving is optional. Many demos only `display(fig)` and stop. When you do save, use an explicit path next to the script:

```julia
path = joinpath(@__DIR__, "my_plot.png")
wsave(path, fig)  # or save(path, fig)
```

Create parent dirs with `mkpath(dirname(path))` when needed. Prefer `wsave`/`save` over custom `@info` + save wrappers.

## No auto-run functions

Don't end with `save_thing()` / `run_thing()` that hide the steps. Let the sequential top-level code be the script.

## Where to put scripts

| Location | Use for |
|----------|---------|
| `scripts/` | Work-relevant workflows: training-run analysis, baseline sweeps, validation, HPC submit wrappers, experiment setup |
| `_research/` | Debugging, one-off probes, small temporary tests while developing |
| `examples/` | Demos and illustrative usage; often display-only, may omit DrWatson |
| `src/` | Structured library code only (functions, keyword args, entry points) — **not** this script style |

Respect project-specific layout from `AGENTS.md` when present.

## Project activation

Pick one import block style; keep it at the top before the first `##`.

**DrWatson project** (typical for `scripts/`, `_research/`):

```julia
using DrWatson
@quickactivate :ProjectName
using MyPackage, CairoMakie
```

**Without DrWatson** (typical for `examples/`, package demos, standalone probes):

```julia
using MyPackage, CairoMakie
# or: using Pkg; Pkg.activate("."); using MyPackage
```

## Templates

**DrWatson workflow** — utilities, setup, display, save:

```julia
# one-line description of what the script does
using DrWatson
@quickactivate :ProjectName
using CairoMakie
##
# utilities
function summarize(x)
    return mean(x), std(x)
end

function plot_field(u; figsize = (800, 600), colormap = :viridis)
    fig = Figure(size = figsize)
    ax = Axis(fig[1, 1])
    heatmap!(ax, u; colormap = colormap)
    return fig
end
##
# setup: params, derived quantities, arrays
ny = 64
u = rand(ny, ny)
## plot
fig = plot_field(u; figsize = (800, 600), colormap = :viridis)
display(fig)
##
path = plotsdir("my_plot.png")
wsave(path, fig)
```

**Example / demo** — display-first, save optional:

```julia
# demonstrate feature X step by step
using MyPackage, WGLMakie
##
# setup
params = default_params(; ny = 64)
env = make_env(params)
##
## 1) visualize
fig, ax = viz!(env; body = true)
display(fig)
##
## 2) run and inspect (no save)
data = run_policy(env, ZeroPolicy())
fig2 = plot_summary(data)
display(fig2)
```

Inline struct/policy definitions in `examples/` are fine when they illustrate API usage.

## Anti-patterns

- Wrapping the whole script in `main()` / `run_analysis()` called at the end
- Saving figures without `display` first
- Putting one-off experiment logic in `src/` instead of `scripts/` or `_research/`
- Defining many small helpers for code used once in the same file
- Putting utility functions in usage sections instead of section 2
- Using `const` for colors, sizes, spacing, or other values you'd tweak while iterating
- Burying tunable defaults inside function bodies instead of keyword arguments
- Declaring locals only to forward them as kwargs (`x = …; f(; x)` / `f(; x = x)`) — put the values inline in the call instead
- Requiring DrWatson/`@quickactivate` in `examples/` when plain `using` suffices
- Ad-hoc save paths in DrWatson projects instead of `plotsdir` / `datadir`
- Forcing a save section in display-only demos

## Related skills

- Plotting: [makie-core](../makie-core/SKILL.md)
- Julia style and formatting: [julia-code](../julia-code/SKILL.md)
