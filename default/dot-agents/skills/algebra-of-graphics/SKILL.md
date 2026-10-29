---
name: algebra-of-graphics
description: Create statistical visualizations in Julia using AlgebraOfGraphics.jl. Use when the user asks for "aog" or "AlgebraOfGraphics" plotting, statistical plots, data visualization with DataFrames, or complex faceted visualizations in Julia. Dont use if desired visualisation is too custom/complex for AoG.
---

# AlgebraOfGraphics.jl

Declarative plotting on Makie. Compose layers with `*` (combine data, mapping, visual) and `+` (overlay), then `draw`.

```julia
using AlgebraOfGraphics, CairoMakie

base = data(df) * mapping(:x, :y, color=:group)    # df: DataFrame, Dict of vectors, or NamedTuple
spec = base * (visual(Scatter, alpha=0.5) + linear())   # points + regression per group
draw(spec; figure = (; size=(800, 600)), axis = (; xlabel="Time (s)"),
     scales = (; color = (; palette=:viridis)))
```

- `mapping`: positional `:x, :y, :z`; keywords `color`, `marker`, `linestyle`, `group` (group without styling); facets `layout`, `row`, `col`. Transform and relabel with `:x => (t -> t^2) => "X squared"`.
- `visual(Plottype; fixed attrs)`: `visual(Scatter, color=:red)` is a fixed colour; `mapping(color=:col)` is data-driven.
- Analyses: `density()`, `histogram(bins=20)`, `frequency()`, `linear()`, `smooth()`, `expectation()`.
- `draw` takes `figure`, `axis` (Makie Axis attributes), `legend`, `colorbar`, `scales` keyword NamedTuples.
- Facet by multiplying `mapping(col=:island)` onto any spec.
- Map styles to columns (`mapping(color=:policy, linestyle=:bound)`) so `draw` builds the legend, with one group per attribute. Do not explain styles in titles or axis labels (see makie-core).

## Troubleshooting

- Nothing shows: `draw(spec)` must be called, and in a script the figure must be displayed explicitly if it is not the last line.
- "Column not found": columns are Symbols (`:colname`) present in the data passed to `data()`.

Docs and gallery: https://aog.makie.org
