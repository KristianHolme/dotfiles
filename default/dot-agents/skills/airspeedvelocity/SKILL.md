---
name: airspeedvelocity
description: Benchmark Julia packages over their commit history using AirspeedVelocity.jl. Use when benchmarking package performance, comparing revisions, or setting up CI benchmarking workflows.
triggers:
  - benchmark package
  - airspeedvelocity
  - benchpkg
  - compare revisions
  - performance regression
---

# AirspeedVelocity.jl

Benchmarks a Julia package across revisions (like Python's `asv`). CLI tools: `benchpkg`, `benchpkgtable`, `benchpkgplot`; run each with `--help` for the full option list.

## Install

```bash
julia -e 'using Pkg; Pkg.activate(temp=true); Pkg.add("AirspeedVelocity"); Pkg.build("AirspeedVelocity")'
```

Executables land in `~/.julia/bin/`; put it on `PATH`.

## Benchmark script

`benchmark/benchmarks.jl` must define `const SUITE = BenchmarkGroup()` (BenchmarkTools syntax); `PACKAGE_VERSION` is available for version-specific code.

```julia
using BenchmarkTools, YourPackage
const SUITE = BenchmarkGroup()
SUITE["feature"]["fast"] = @benchmarkable your_function(args...)
```

## Run

```bash
benchpkg                                   # current dir vs default branch
benchpkg YourPackage -r v0.4.20,v0.4.70,master -o results/
benchpkg -r dirty -a ExtraPkg1,ExtraPkg2   # uncommitted changes; -a = benchmark-only deps
benchpkg YourPackage -s path/to/script.jl -e "--threads=4 -O3" --tune
benchpkgtable YourPackage -r v1,v2 -i results/ --ratio --mode=time,memory
benchpkgplot YourPackage -r v1,v2 -i results/ -o plots/ --format=pdf
```

- `--bench-on <rev>` takes the benchmark script from that revision (freeze it across revisions).
- `-f <pattern>` runs only matching benchmarks during development.
- `--tune` is more accurate but slower.
- `-o`/`-i` set the JSON results directory (default `.`).

## CI

Read [references/ci.md](references/ci.md) when setting up GitHub Actions (PR comment or job summary).
