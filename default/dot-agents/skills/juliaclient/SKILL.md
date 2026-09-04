---
name: juliaclient
description: Run Julia code through juliaclient, the CLI for the julia-daemon worker pool. Use when evaluating Julia expressions, running Julia scripts, profiling, or benchmarking, or when the user mentions juliaclient, julia-daemon, or persistent Julia sessions.
---

# juliaclient

`juliaclient` is a drop-in replacement for `julia` for `-e`/`-E`/script runs,
backed by warm worker processes managed by the `julia-daemon` user service.
Prefer it over `julia` — same flags, no startup or compile wait.

## Basics

```sh
juliaclient -e 'println(1 + 1)'          # evaluate, output via stdout
juliaclient -E '1 + 1'                   # evaluate and display the result
juliaclient script.jl                    # run a file (cwd is honored)
juliaclient --project=. -e 'using Pkg; ...'
juliaclient -t 4 -e '...'                # thread count (separate worker pool)
juliaclient --status                     # workers, sessions, memory
```

Every call runs in a **fresh module** — no state leaks between calls.
Use this stateless default for idempotent steps; nothing needs restarting.

## Sessions (only when state must persist across calls)

```sh
juliaclient --session=<unique-label> -e '...'
```

- Runs in the worker's `Main`, so globals survive across calls.
- Each label gets its own worker: state is isolated per label.
- One label per agent/task, never shared — a shared label means shared `Main`.

## Restarting one session without touching the others

`juliaclient --restart` kills **every** worker for the project — never use it
to reset a single session. Instead kill only your own worker:

```sh
kill $(juliaclient --status=json | jq -r '.workers[] | select(.session_label=="<label>") | .pid')
```

The next call with that label cold-starts fresh; other sessions are unaffected.
Abandoning a label also works, but pins ~500 MB until its TTL expires (~15 min+).

## Notes

- Installed by dotfiles: `bin/julia-setup.jl` adds DaemonicCabal and enables the
  service (see `packages.toml [julia.daemon]`). Re-run `DaemonicCabal.install()`
  after `juliaup update`, since the worker binary path is baked into the service.
- Daemon control: `systemctl --user {status,restart} julia-daemon`
  (a daemon restart resets everything for all projects).
