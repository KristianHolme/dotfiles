---
name: juliaclient
description: Run Julia code through juliaclient, the CLI for the julia-daemon worker pool, the default way to run Julia here. Use for every Julia expression, script, profile, or benchmark unless the process must be fresh (see "When to use plain julia"); also when the user mentions juliaclient, julia-daemon, or persistent Julia sessions.
---

# juliaclient

`juliaclient` is a drop-in replacement for `julia` for `-e`/`-E`/script runs,
backed by warm worker processes managed by the `julia-daemon` user service.
Same flags, no startup or compile wait: a warm worker already holds the loaded
packages, so the second and later calls in a task run in seconds. Agents make
many Julia calls per task; default to `juliaclient` for all of them. See
`juliaclient --help` for details.

## When to use plain `julia`

Use `julia` when the process itself is the thing under test or control:

- precompile, `Pkg.instantiate`/`add`/`update`/`test`, or any call that must
  start from a clean process and clean depot state
- per-process settings: env vars such as `CUDA_VISIBLE_DEVICES`, `--threads`,
  `--check-bounds`, `--sysimage`
- jobs launched through `sbatch` or `nohup` on a host without a working daemon
- `juliaclient` fails: exit 132, "daemon not running", or a connection error

Check once per task on the current host:

```sh
juliaclient -e 'println(1+1)'   # prints 2 when it works
```

If that fails, run `julia` for the rest of the task. The daemon runs per host
(`systemctl --user is-active julia-daemon`); `systemctl --user start
julia-daemon` starts it. An exit 132 means the executables use CPU instructions
this host lacks; see [references/install.md](references/install.md).

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

## Iterating on package code (Revise)

When editing a package's `src/` and re-running it, pass `--revise=yes` on every
call. Revise applies the edit to the warm worker (the project's own package and
`dev`-ed dependencies), so an iteration costs seconds, not a restart or a
recompile. It works with `--session=<label>` too.

- Revise only tracks packages loaded after it. The worker must start with
  `--revise=yes`; on a worker that already loaded the package without it, the
  flag does nothing. Kill that project's worker once, then continue with the flag:

```sh
kill $(juliaclient --status=json | jq -r '.workers[] | select(.project=="'"$PWD"'") | .pid')
```

- An edit made a moment before the call can still be missed. Repeat the call,
  or run `using Revise; Revise.revise()` inside it.
- Revise cannot apply every edit (struct definitions, `const` redefinitions).
  Kill the worker for those.

## Stale package code without Revise

A fresh module per call does NOT mean fresh packages. The worker for a project
stays alive between calls (until culled) and keeps every loaded package. After
you edit a package's `src/` without `--revise=yes`, the next call runs the OLD
code, with no recompile. A warning `Running outdated code: these changed on
disk` marks this. Runtime patches (`@eval SomePkg f(...) = ...`) leak into later
calls in the same way. Kill the worker (command above) before the next call.

`juliaclient --project --restart` can report `killed 0 worker(s)` while a
worker for the project is running, so do not rely on it.

## Look up the rest

- Install, artifact override, rebuild after `juliaup update` → [references/install.md](references/install.md)
