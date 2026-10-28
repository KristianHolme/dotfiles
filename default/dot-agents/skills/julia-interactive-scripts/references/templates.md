# Script templates

**DrWatson workflow**: utilities, setup, plot, save:

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
isinteractive() && display(fig)
##
path = plotsdir("my_plot.png")
wsave(path, fig)
```

**Example / demo**: display-first, save optional:

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
isinteractive() && display(fig)
##
## 2) run and inspect (no save)
data = run_policy(env, ZeroPolicy())
fig2 = plot_summary(data)
isinteractive() && display(fig2)
```

Inline struct/policy definitions in `examples/` are fine when they illustrate API usage.
