# Precompile and cache-load failures

Diagnose before you change anything. Do not work around a failure with serial precompile (`JULIA_NUM_PRECOMPILE_TASKS=1`), `--compiled-modules=existing|no`, or a second depot.

## `Precompiled image <Pkg> not available with flags CacheFlags(...)`

Parallel precompile workers run with `--compiled-modules=strict`. A strict worker that finds no usable cache for a dependency fails with this message. The `CacheFlags(...)` part prints only the worker's own flags. It does not mean a flags mismatch. The cause is a missing or invalid cache for `<Pkg>`, for example a `.ji` without its matching `.so`.

Fix: with the user's OK, delete only that package's directory, `~/.julia/compiled/v<X.Y>/<Pkg>/`, then rerun `Pkg.precompile()`. Never delete the whole `compiled/v<X.Y>`.

## Many unrelated packages fail the same way

The usual cause is caches built for one CPU target. A Julia process started without the machine's `JULIA_CPU_TARGET` (for example a daemon or service that does not read the shell profile) writes single-target caches into the same slots. Pkg treats them as fresh, and the strict worker rejects them.

- Confirm: run precompile with `JULIA_DEBUG=loading` and look for `Rejecting this target due to use of runtime-disabled features`.
- `.ji`/`.so` mtimes are not evidence: Pkg touches `.ji` files when it checks them.
- Find them all: for each `.ji`, check `Base.isvalid_cache_header`, then read `Base.parse_cache_header(io, path)[6]` and `Base.parse_image_targets`. List the files with one target.
- Fix: with the user's OK, delete those `.ji`/`.so` pairs, fix the process that lacked `JULIA_CPU_TARGET`, and rerun `Pkg.precompile()`.

If a fix would disturb running Julia sessions, stop and ask.
