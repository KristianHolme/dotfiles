---
name: julia-profiling-agent
description: Run Julia CPU or allocation profiling and produce token-efficient reports for coding agents. Use when optimizing performance, identifying bottlenecks, or when the user asks for profiling workflows, profile output storage, or agent-friendly profile summaries.
---

# Julia Profiling for Coding Agents

Workflow for agents to profile Julia code in a **persistent `juliaclient` session** (`juliaclient --session=<label>`, see the juliaclient skill), then inspect results without writing to file unless the user wants to.

## Use a juliaclient session

Run all profiling and inspection in the **same `juliaclient --session=<label>` session**. Do not start one-off `julia -e` processes for profiling — cold starts are slow and `Profile` state would not carry over. (Plain `juliaclient` without `--session` also starts fresh every call, so the label is what keeps `Profile` state and `(data, lidict)` alive.) The session keeps `Profile` state and `(data, lidict)` from `Profile.retrieve()` so the agent can:

- Run `Profile.@profile <expr>`, then `Profile.retrieve()` once.
- Print a short summary (e.g. to an `IOBuffer`), read the string, and use only the first N lines in context.
- Dive deeper in the same session (e.g. `Profile.callers(...)`, or another `Profile.print` with different options) without re-profiling.

Do **not** save the profile to a file unless the user explicitly wants to inspect it (e.g. open in an editor or share).

## Two-phase workflow

### 1. Short summary first

After `Profile.clear()` and `Profile.@profile <expr>`:

- Get `data, lidict = Profile.retrieve()`.
- Print a **flat, count-sorted, mincount-filtered** report into an `IOBuffer`, then take the string and use only the **first 20–40 lines** (header + top hotspots) for the agent’s context. That keeps tokens low.

Example pattern — run the whole block in one `juliaclient --session=<label>` call (e.g. `juliaclient --session=prof -E 'begin ... end'`, or put it in a script and run `juliaclient --session=prof script.jl`):

```julia
using Profile
Profile.clear()
Profile.@profile my_slow_function()
data, lidict = Profile.retrieve()
io = IOBuffer()
Profile.print(io, data, lidict; format = :flat, sortedby = :count, mincount = 20)
s = String(take!(io))
# Use only first 30–40 lines of s for analysis (e.g. split(s, '\n')[1:35])
```

Options for the summary:

- `format = :flat`, `sortedby = :count` — one line per location, hottest first.
- `mincount = N` — drop noise (e.g. 10–50 for short runs, or ~1–5% of total sample count).
- Restrict to the first N lines of the string so the agent only sees the top hotspots.

### 2. Dive deeper only if needed

If the short summary suggests a specific bottleneck (function or file:line), use the **same** `data, lidict` in the same session:

- **Who called this?** `Profile.callers("funcname", data, lidict)` or `Profile.callers(func, data, lidict)`. Optionally narrow with `filename` and `linerange`.
- **Tree view for context?** `Profile.print(io, data, lidict; format = :tree, maxdepth = 15, mincount = 5)` into an IOBuffer and use the first portion of the string.
- **More flat detail?** Lower `mincount` or print again and take more lines.

No need to re-run the workload; `data` and `lidict` stay valid for the session.

## Built-in Profile API (reminder)

- **CPU**: `Profile.@profile <expr>` then `Profile.retrieve()` or `Profile.print(...)`.
- **Allocation**: `Profile.Allocs.@profile [sample_rate=0.001] <expr>` then `Profile.Allocs.fetch()` / `Profile.Allocs.print()` (or PProf/visualizers).
- **Wall-time** (I/O, contention): `Profile.@profile_walltime <expr>`.

No extra packages required for CPU profiling and text summaries.

## When to write profile output to a file

Only when the **user** wants to inspect the profile (e.g. open in editor, attach to a report). Then write the same flat or tree report to a path they choose (e.g. `/tmp/julia_profile_flat.txt` or `tmp/profile_flat.txt` in the workspace). Do not write to file by default for the agent’s own analysis.

## Programmatic use (same session)

- **Callers**: `Profile.callers("funcname", data, lidict)` or `Profile.callers(func, data, lidict)`; optional `filename` and `linerange` to disambiguate.
- **Flatten inlined frames**: `Profile.flatten(data, lidict)` if you need a 1-to-1 IP-to-StackFrame mapping for custom analysis.

## Optional: PProf.jl + pprof CLI

If the user has PProf.jl and the pprof CLI and wants a file (e.g. for external inspection): after profiling, `pprof(out = "/tmp/profile.pb.gz")`, then `pprof -top -text -nodecount=30 profile.pb.gz` for a compact report. For in-session, token-efficient analysis, the built-in `Profile.print` to an IOBuffer and using the first N lines is enough.

## Allocation profiling

Use `Profile.Allocs.@profile sample_rate=0.0001` (or similar), then `Profile.Allocs.fetch()` or `Profile.Allocs.print()`. For a short summary in-session, print to an IOBuffer and use the first N lines; write to file only if the user wants to inspect it.

## Summary for the agent

1. Use one **`juliaclient --session=<label>`** session for all profiling and inspection.
2. Run `Profile.@profile <expr>`, then `Profile.retrieve()`.
3. **First**: print a short summary (flat, sortedby=:count, mincount) to an **IOBuffer**, take the string, and use only the **first 20–40 lines** to identify likely bottlenecks.
4. **If needed**: dive deeper with `Profile.callers(...)` or another `Profile.print` (e.g. tree, lower mincount) using the same `data, lidict` — no re-profile, no file.
5. Write profile output to a file **only** when the user wants to inspect it.
