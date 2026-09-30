---
name: julia-profiling
description: Profile Julia code headlessly to find bottlenecks — CPU hot spots, runtime dispatch, GC pressure, allocations, type instabilities — and produce token-efficient reports. Use whenever the user asks why Julia code is slow, wants it faster, mentions allocations or type instability, or asks to profile or benchmark something, even if they do not say "profile".
---

# Julia profiling

Measure, profile, and report. Do not rewrite code silently: propose optimizations tied
to evidence and get the user's agreement before editing. For the fixes themselves, see
[julia-performance-tips](../julia-performance-tips/SKILL.md).

The target (a call, a script, a test) comes from the user. If unclear, ask for a concrete
entry point and representative arguments.

## Setup: one juliaclient session

Run everything in one persistent session (see [juliaclient](../juliaclient/SKILL.md)):

```sh
juliaclient --project=<project> --session=prof-<topic> [--revise=yes] -E 'begin ... end'
```

The session keeps compiled code, `Profile` buffers, and `(data, lidict)` alive between
calls. Plain `juliaclient` without `--session` starts a fresh module each call, so profile
state would not carry over. Use `--revise=yes` when you will edit `src/` between runs.

`Profile`, `FlameGraphs`, and `BenchmarkTools` live in the base environment (`@v#.#`).
Never add them to the project's `Project.toml`. Optional: `Cthulhu`. Do not use ProfileView:
it is GUI-only; FlameGraphs is its data layer.

Keep output small: print reports into an `IOBuffer` and return only the first 20–40
lines or an aggregated table. Write profile output to a file only when the user wants to
inspect it.

## 1. Warm up

Run the target once before measuring. The first run measures the compiler. Discard it.

## 2. Baseline

```julia
using BenchmarkTools
t = @benchmark myfunc($arg1, $arg2)
(; t_ns = time(median(t)), bytes = memory(minimum(t)), allocs = allocs(minimum(t)),
   gc_frac = gctime(median(t)) / time(median(t)))
```

- Interpolate every external value with `$`. Without it you measure global lookup.
- Use `@benchmark` (returns a `Trial`), not `@btime` (prints; returns the expression value).
- For runs of seconds or more, use `@timed` once instead; `@benchmark` would run it
  several times for one usable sample.

A large GC fraction points to step 4. Sub-millisecond code needs `@bprofile` in step 3.

## 3. CPU profile

```julia
using Profile, BenchmarkTools, FlameGraphs
Profile.clear()
@bprofile myfunc($arg1, $arg2)          # fast code: many runs, clears the buffer itself
# Profile.@profile myfunc(arg1, arg2)   # slow code: one run
```

- `Profile.@profile` appends to the buffer. Call `Profile.clear()` first, unless you
  want to combine several call paths into one profile on purpose.
- The buffer has a fixed size; when full, sampling stops and `fetch` warns about
  truncation. Read the current settings with `Profile.init()`. For runs ≳20 s coarsen
  the interval (`Profile.init(; delay = 0.01)`); for shorter runs with deep stacks keep
  `delay` and raise `n`.
- I/O-bound or task-heavy code: `Profile.@profile_walltime` (Julia 1.12+).

### Quick flat summary

```julia
data, lidict = Profile.retrieve()
io = IOBuffer()
Profile.print(io, data, lidict; format = :flat, sortedby = :count, mincount = 20)
join(first(split(String(take!(io)), '\n'), 35), '\n')
```

`mincount` drops noise (10–50 for short runs, or ~1–5% of total samples). Drill down
in the same session without re-profiling: `Profile.callers("funcname", data, lidict)`,
or `Profile.print(io, data, lidict; format = :tree, maxdepth = 15, mincount = 5)`.

### Dispatch and GC sites (FlameGraphs)

`flamegraph()` returns a traversable tree. Each `node.data` has `sf` (a `StackFrame`),
`span` (`length(span)` = samples), and `status`, a bitfield with
`FlameGraphs.runtime_dispatch` (`0x01`) and `FlameGraphs.gc_event` (`0x02`). Runtime
dispatch frames are the prime optimization target.

```julia
function flatten_fg(node, rows = Any[])
    total = length(node.data.span)
    childtotal = 0
    for c in node
        childtotal += length(c.data.span)
        flatten_fg(c, rows)
    end
    push!(rows, (; sf = node.data.sf, total, self = total - childtotal, status = node.data.status))
    return rows
end

rows = sort!(flatten_fg(flamegraph()); by = r -> -r.self)
dispatch = filter(r -> r.status & FlameGraphs.runtime_dispatch != 0, rows)
gc = filter(r -> r.status & FlameGraphs.gc_event != 0, rows)
first(rows, 15), first(dispatch, 10), first(gc, 10)
```

One function appears once per call path; aggregate `self`/`total` by
`(sf.func, sf.file, sf.line)` for a per-function view.

## 4. Allocation profile

When step 2 showed allocations or GC time:

```julia
Profile.Allocs.clear()
Profile.Allocs.@profile sample_rate = 0.1 myfunc(arg1, arg2)
allocs = Profile.Allocs.fetch().allocs
bytes_by_type = Dict{Any, Int}()
bytes_by_site = Dict{Any, Int}()
for a in allocs
    bytes_by_type[a.type] = get(bytes_by_type, a.type, 0) + a.size
    isempty(a.stacktrace) && continue
    bytes_by_site[a.stacktrace[1]] = get(bytes_by_site, a.stacktrace[1], 0) + a.size
end
first(sort(collect(bytes_by_type); by = last, rev = true), 10),
first(sort(collect(bytes_by_site); by = last, rev = true), 10)
```

`sample_rate`: `1.0` exact but slow, `0.1` default, `0.01` or lower for long runs (counts
are then estimates). On Julia 1.10 some types show as `Profile.Allocs.UnknownType`; use
Julia ≥1.11 for allocation work.

## 5. Type instabilities

For the costliest dispatch frames:

- `using Test; @inferred f(args...)` — throws if the return type is not concrete.
- `@code_warntype f(args...)` — look for `::Any`, `::Union{...}`, and `Core.Box`
  (a captured variable that is reassigned).
- `jetls check` or JET's `@report_opt` for whole-call-graph dispatch reports.
- Cthulhu's `@descend` is a TUI, not agent-drivable; follow chains manually with
  `@code_warntype` on each unstable callee.

## 6. Report and propose

- Baseline numbers: time, allocations, GC fraction.
- Top self-cost frames with `file:line`.
- Top runtime-dispatch frames and the instability behind each.
- Top allocation types and sites.
- Prioritized proposals, each tied to the evidence, with the expected biggest win first.

After an approved change, re-run steps 1–2 in the same session and confirm with
`judge(median(after), median(before))` that it is an improvement, not noise.

## Optional: PProf

For a file the user wants to open elsewhere: `pprof(out = "/tmp/profile.pb.gz")`, then
`pprof -top -text -nodecount=30 /tmp/profile.pb.gz`.

<!-- Steps 2–5 adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
