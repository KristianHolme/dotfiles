# Profiling recipes

## Dispatch and GC sites (FlameGraphs)

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


## Allocation profile

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

