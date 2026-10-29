---
name: juliaclient
description: Run Julia code through juliaclient, the CLI for the julia-daemon worker pool. Use when evaluating Julia expressions, running Julia scripts, profiling, or benchmarking, or when the user mentions juliaclient, julia-daemon, or persistent Julia sessions.
---

# juliaclient

`juliaclient` is a drop-in replacement for `julia` for `-e`/`-E`/script runs,
backed by warm worker processes managed by the `julia-daemon` user service.
Prefer it over `julia` — same flags, no startup or compile wait. See
`juliaclient --help` for details.

## Sessions (only when state must persist across calls)

```sh
juliaclient --session=<unique-label> -e '...'
```

Without `--session`, every call runs in a fresh module — nothing leaks between
calls, nothing needs restarting. With a label, code runs in the worker's
`Main`, so globals survive; each label gets its own worker. One label per
agent/task, never shared.

## Restarting one session without touching the others

`juliaclient --restart` kills every worker for the project — never use it to
reset a single session. Instead kill only your own worker:

```sh
kill $(juliaclient --status=json | jq -r '.workers[] | select(.session_label=="<label>") | .pid')
```

## Stale package code after editing source

A fresh module per call does NOT mean fresh packages. The worker for a project
stays alive between calls (until culled) and keeps every loaded package. After
you edit a package's `src/`, the next call runs the OLD code — no error, no
recompile. Runtime patches (`@eval SomePkg f(...) = ...`) also leak into later
calls in the same way.

- Use `--revise=yes` on calls that must see `src/` edits, or
- kill that project's worker before the call:

```sh
kill $(juliaclient --status=json | jq -r '.workers[] | select(.project=="'"$PWD"'") | .pid')
```

`juliaclient --project --restart` can report `killed 0 worker(s)` while a
worker for the project is running, so do not rely on it. Sign of stale code: a
run that should recompile finishes in a few seconds.

## Look up the rest

- Install, artifact override, rebuild after `juliaup update` → [references/install.md](references/install.md)
