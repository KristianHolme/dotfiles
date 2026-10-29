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
- Prefer modular plotting functions that accept a `GridPosition` or `Axis`, e.g. `build_summary_panel!(ax, data; kwargs...)`, composed by `build_figure(data; kwargs...) -> Figure`.
- For complex figures, organize code by layout areas and use nested `GridLayout` sections to keep structure readable.
- Keep functions small and focused: one axis/plot per function when possible.
- Use mutating plot methods (`lines!`, `scatter!`, etc.) when plotting into existing axes.
- Use non-mutating methods (`lines`, `scatter`, etc.) only when creating a new axis/plot from a `GridPosition`.

## Layouts and Axes
- Create a top-level `Figure()` and place plots via `fig[row, col]`.
- Use nested layouts with `fig[row, col][subrow, subcol]` to build sections.
- Prefer explicit `Axis` creation for clarity in complex layouts.
- Use `Colorbar` and `Legend` in adjacent layout cells rather than overlaying.
- Explain what colour, line style or marker means in a `Legend`, not in titles or axis labels: no `"Reward (dashed: run1, solid: baseline)"`. Titles name the quantity only. A direct label or annotation next to a line is fine when it reads better.
- When visuals vary along more than one attribute (colour, line style, marker, …), use a multi-group `Legend` with one group per attribute, e.g. colour = policy, line style = bound: `Legend(fig[1, 2], [policy_entries, style_entries], [policy_labels, style_labels], ["Policy", "Bound"])`.

## Ask Before Building Static Plots
If a static plot may be reused later in dynamic visualizations, ask whether the user wants the data inputs wired through `Observable`s from the start.

## Themes and Defaults
- Use `set_theme!` or `update_theme!` to keep styling consistent across figures.
- Prefer explicit axis labels and titles for clarity.

## Saving
Guard display with `isinteractive() && display(fig)`. A human in a REPL sees the figure; a headless run by the agent only saves, so no window pops up on the user's desktop. Inspect saved files by reading them.
