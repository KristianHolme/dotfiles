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
  from https://github.com/tecosaur/DaemonicCabal.jl. `install()` hardlinks
  `artifact"execbundle"`; it does not compile the executables. Build both Zig
  programs from the same source revision as the Julia worker, then replace the
  installed executables before starting the service when the published bundle
  does not match that revision.
- Overlay lives in **the first depot**, not always `~/.julia`:
  `$JULIA_DEPOT_PATH/artifacts/Overrides.toml`. Use a **content-hash** line, not a
  `[uuid]` table — `artifact"execbundle"` never passes the package UUID:

      9855c7292594fe8c8389b5027b010925c5eca2bc = "/absolute/path/to/execbundle"

  That hash is the linux-x86_64 `git-tree-sha1` in the package `Artifacts.toml`.
  Update the override if it changes. The path must be absolute.
- Overlay dirs: HPC
  `/cluster/projects/nn9886k/kholme/.julia/artifacts/overrides/execbundle`;
  laptop `~/.local/share/julia/daemoniccabal-execbundle`. Keep the override
  binaries aligned with the package source revision and rebuild them after
  changing that revision.
- After `juliaup update`, re-run `DaemonicCabal.install()` if the artifact
  override is present, then verify that the installed executables still match
  the worker source revision.
