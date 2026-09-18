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
  fallback for Linux 4.18). The fork's Zig has epoll, but `install()` does not
  compile it: it hardlinks `artifact"execbundle"`, which still downloads
  tecosaur 0.5.0 (io_uring-only). Overlay:
  `~/.local/share/julia/daemoniccabal-execbundle`.
- `~/.julia/artifacts/Overrides.toml` must be a **content-hash** line, not a
  `[uuid]` table — `artifact"execbundle"` never passes the package UUID:

      9855c7292594fe8c8389b5027b010925c5eca2bc = "/absolute/path/to/daemoniccabal-execbundle"

  That hash is the linux-x86_64 `git-tree-sha1` in the package `Artifacts.toml`.
  Update the override if it changes. The path must be absolute.
- After `juliaup update`, re-run `DaemonicCabal.install()` only if that hash
  override is still present. A plain `install()` without it hardlinks the
  official binary; the conductor then exits `SystemOutdated` on Linux 4.18.
  Rebuild the overlay with Zig 0.16 from `~/Code/DaemonicCabal.jl` (toolchain in
  `~/.local/share/zig/zig-x86_64-linux-0.16.0`, not `/tmp`) if the overlay path
  is missing.
