# juliaclient install notes

Read when installing, rebuilding, or debugging the daemon executables.

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
- On the UiO shared home, build both Zig programs with `JULIA_DAEMON_CPU=haswell`
  (exported by `default/dot-bashrc-uio-math`, read by `bin/julia-setup.jl` as
  `-mcpu=haswell`). The default native target emits AVX-512, and `juliaclient` then
  dies with `Illegal instruction` (exit 132) on abacus-as and abacus-min, which lack
  it. Single machines leave it unset. Check a build with
  `objdump -d <exe> | grep -c -E 'zmm|%k[0-7]'`; the count is 0.
