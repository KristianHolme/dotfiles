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

## Notes

- Installed by dotfiles (`bin/julia-setup.jl`, see `packages.toml [julia.daemon]`)
  from https://github.com/KristianHolmeAgenticWorkspace/DaemonicCabal.jl (epoll
  fallback for Linux 4.18). Re-run `DaemonicCabal.install()` after `juliaup update`.
  Published 0.5.0 artifacts are still io_uring-only; this host overlays a Zig 0.16
  build via `~/.julia/artifacts/Overrides.toml`.
