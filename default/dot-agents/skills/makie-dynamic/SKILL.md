---
name: makie-dynamic
description: Makie animations, dashboards, and interactive visualizations using Observables, events, and UI widgets.
---

# Makie Dynamic

Use Makie (not a specific backend) for all plotting. Assume all features are available.

## Reactivity with Observables
- Use `Observable` values as the single source of truth for dynamic state.
- Prefer `lift` or `@lift` to derive dependent data reactively.
- After in-place mutation of an observable value (e.g. `obs[] .= ...`), call `notify(obs)`.
- Use `on(obs)` for side effects and `lift` for pure transformations.

## Animations and Recording
- For recording, use `record(fig, "out.mp4", iterator) do frame ... end` and update observables inside the loop.
- Avoid manual `sleep` loops or `@async` timers for animation.
- Use `events(fig).tick` for frame-aligned updates in interactive sessions.

## UI Widgets
- Sliders: bind `slider.value` to observables; use `@lift` to connect to plot data.
- Buttons: use `on(button.clicks)` for actions (play/pause, reset, step).
- Toggles: gate updates by `toggle.active[]` to enable/disable behavior.
- Menus/Textboxes: use `selection` or `value` observables to drive state.

## Events and Interaction
- Use `events(fig)` or `events(ax)` for mouse/keyboard/scroll events.
- If needed, return `Consume(true)` to stop lower-priority handlers.

## Dashboards and Structure
- Keep dashboard state in a small set of observables (or a struct holding them).
- Split UI and plot construction into functions that accept `GridPosition` or `Axis`.
- On Makie 0.25+, use a `Subfigure`'s scene theme to isolate independently themed dashboard regions.
- For larger dashboards, consider using `Makie.SpecApi` to build declarative layouts.

## Performance Notes
- Update plot data in-place when possible, and notify explicitly.
- Avoid rebuilding axes/plots each frame; update existing plot objects.
- For heavy pipelines, evaluate whether Makie’s compute pipeline tools are appropriate.
