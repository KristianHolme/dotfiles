# performance-exploration

Use juliaclient (see the juliaclient skill) to explore alternative implementations.
Benchmark code against current implementation, using BenchmarkTools (available in base env).

## Suggested workflow

- Make scripts with implementations in `_research/performance` if the folder exists (may ask user to create it if not present)
- Run them with `juliaclient` so every run is warm — no Julia startup cost per benchmark.
- For iterative work, use one session (`juliaclient --session=perf-<topic>`) and `include` the files there; with `--revise`, `includet` keeps the functions updated as the files are edited.
- Restart only your own session when state goes stale (see juliaclient skill). Never `juliaclient --restart` — it resets every session in the project.
- Run benchmarks with `juliaclient -e`/`-E` against the functions in the script.
