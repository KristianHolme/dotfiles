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

## CUDA fails on a GPU host: `CUDA.functional()` false, `JLLs were precompiled without an NVIDIA driver`, `CUDA runtime not found`, `libnvJitLink.so.13: cannot open`

A Julia process on a host without an NVIDIA driver wrote `cuda = "none"` caches into a depot that GPU hosts share. Julia keeps choosing them, and `Base.compilecache` on the GPU host does not replace them.

- Find them: in `~/.julia/compiled/v<X.Y>/`, the `CUDA_Runtime_jll`, `CUDA_Compiler_jll`, `CUDA_Driver_jll` and `CUDACore` files that share one mtime burst. A driverless `CUDA_Runtime_jll` or `CUDA_Compiler_jll` `.so` is about 1.16 MB; a good one is about 1.56 MB. `Base.pkgorigins[...]` `.cachepath` on the GPU host names the chosen files.
- Fix: delete every `.ji`/`.so` pair of that burst and keep older ones, which other environments use. Then load the project once on a GPU host (`using CUDA; CUDA.functional()`) before you start several jobs: jobs that start together on a stale cache race the precompile.

If a fix would disturb running Julia sessions, stop and ask.
