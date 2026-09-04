---
name: makie-core
description: >-
  Core Makie plotting, layouts, and modular figure construction. Use for any
  Julia plotting (Makie only — not Plots.jl), static figures, layouts, axes, or
  general Makie usage.
---

# Makie Core

Use Makie (not a specific backend) for all plotting. Assume all features are available.

## Core Principles
- Prefer modular plotting functions that accept a `GridPosition` or `Axis`, e.g. `plot_part_A!(ax, data; kwargs...)`.
- For complex figures, organize code by layout areas and use nested `GridLayout` sections to keep structure readable.
- Keep functions small and focused: one axis/plot per function when possible.
- Use mutating plot methods (`lines!`, `scatter!`, etc.) when plotting into existing axes.
- Use non-mutating methods (`lines`, `scatter`, etc.) only when creating a new axis/plot from a `GridPosition`.

## Layouts and Axes
- Create a top-level `Figure()` and place plots via `fig[row, col]`.
- Use nested layouts with `fig[row, col][subrow, subcol]` to build sections.
- Prefer explicit `Axis` creation for clarity in complex layouts.
- Use `Colorbar` and `Legend` in adjacent layout cells rather than overlaying.

## Modularity Pattern (Recommended)
- Build figures by composing functions:
  - `build_summary_panel!(ax, data; kwargs...)`
  - `build_detail_panel!(ax, data; kwargs...)`
  - `build_figure(data; kwargs...) -> Figure`

## Ask Before Building Static Plots
If a static plot may be reused later in dynamic visualizations, ask whether the user wants the data inputs wired through `Observable`s from the start.

## Themes and Defaults
- Use `set_theme!` or `update_theme!` to keep styling consistent across figures.
- Prefer explicit axis labels and titles for clarity.
