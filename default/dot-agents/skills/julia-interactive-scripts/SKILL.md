---
name: julia-interactive-scripts
description: Write Julia scripts for interactive REPL work — sectioned, top-level flow, display only when interactive. Use when creating or editing files in scripts/, _research/, or examples/, or when the user asks for analysis, plotting, validation, or one-off experiment scripts (not library code in src/). Covers both DrWatson projects and plain using/Pkg.activate demos without DrWatson.
---

# Julia Interactive Scripts

Scripts are for **interactive REPL work** (include / run section by section), not library code. Prefer flat, sectioned scripts over wrapping logic in functions. A short comment before the imports saying what the script does is fine; don't turn the script into a small API.

## Layout

`##` markers split sections so blocks re-run independently. Order:

1. **Imports and activation**: above the first `##`, in one block (no `##`).
2. **Utilities**: helper functions reused within the file (first `##`), following [julia-code](../julia-code/SKILL.md) (explicit `return`, Runic).
3. **Constants**: only truly immutable values (a physical dimension baked into the model, a fixed file extension); skip when nothing qualifies. Not for colors, sizes, spacing or other knobs you tweak between runs.
4. **Usage**: setup, compute, plot, save (remaining `##`). Numbered sections (`## 1) …`) are fine in tutorial-style `examples/` usage sections only.

## Top-level flow

- Compute at script scope with plain assignments (`ny = 64`, `params = …`). Avoid helpers unless the logic is reused in the same file.
- Tunable defaults are keyword arguments (`function plot_result(data; color = :steelblue)`), not buried in bodies.
- **Call-site knobs go inline.** Pass overrides directly (`plot_field(u; figsize = (800, 600), colormap = :viridis)`); don't declare locals only to forward them (`x = …; f(; x)`).
- No `main()` / `run_thing()` wrappers or auto-run functions at the end; the sequential top-level code is the script.

## Display only when interactive

Write `isinteractive() && display(fig)` in the plot section. A REPL/IDE user sees the figure; a headless run (`julia script.jl`, `julia -e`, juliaclient) skips it, so no window pops up on the user's desktop. See [makie-core](../makie-core/SKILL.md).

## Save in its own section

Use a separate `##` block at the bottom, never a wrapper function.

- **DrWatson** (`scripts/`, `_research/`): `plotsdir(...)` / `datadir(...)` with `wsave(path, fig)` (or `safesave`), not ad-hoc paths.
- **Without DrWatson** (`examples/`, demos): saving is optional; don't force a save section in display-only demos. When saving, use a path next to the script: `path = joinpath(@__DIR__, "my_plot.png"); wsave(path, fig)` (`mkpath(dirname(path))` if needed).

## Project activation

DrWatson (typical for `scripts/`, `_research/`):

```julia
using DrWatson
@quickactivate :ProjectName
using MyPackage, CairoMakie
```

Without DrWatson (`examples/`, demos; don't require `@quickactivate` there):

```julia
using MyPackage, CairoMakie
# or: using Pkg; Pkg.activate("."); using MyPackage
```

## Where to put scripts

| Location | Use for |
|----------|---------|
| `scripts/` | Work workflows: training-run analysis, sweeps, validation, HPC submit wrappers, experiment setup |
| `_research/` | Debugging, one-off probes, temporary tests |
| `examples/` | Demos and illustrative usage; often display-only, may omit DrWatson |
| `src/` | Structured library code only; one-off experiment logic does not go here |

Respect project-specific layout from `AGENTS.md`.

## Look up the rest

- Full script templates (DrWatson workflow, example/demo) → read [references/templates.md](references/templates.md) when writing a new script from scratch.
