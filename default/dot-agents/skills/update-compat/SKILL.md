---
name: update-compat
description: Update a Julia package's [compat] to allow a new breaking version of a dependency, then fix whatever the upgrade breaks. Use when the user says a dependency has a new major/breaking release, asks to "bump compat", "allow version X of Y", or a CompatHelper PR needs finishing by hand.
disable-model-invocation: true
---

Update the package in the current directory to allow a new breaking version of a dependency. The dependency name and new version should be specified by the user; ask if not provided.

Two kinds of Julia invocation are used here, for different reasons. One-shot `julia --project -e ...` processes give clean, reproducible results for the baseline and final test runs and for `Pkg` operations. The iterative fix loop uses a `juliaclient` session with Revise so compilation is amortized across attempts (see the `juliaclient` skill).

Changing `[compat]` edits `Project.toml`; the user asked for it by invoking this skill, but confirm the exact range before writing it (see `julia-project`).

## 1. Verify baseline

Run the test suite in a fresh process and confirm everything passes before making any changes:
```
julia --project -e 'using TestEnv; TestEnv.activate(); include("test/runtests.jl")'
```

Do not proceed if any tests fail: the upgrade's breakage cannot be distinguished from pre-existing failures. Report the failures to the user and stop.

## 2. Bump [compat]

In `Project.toml`, update the `[compat]` entry for the dependency to include the new version. Preserve the existing lower bound unless the user instructs otherwise.

## 3. Update and verify resolver selection

```
julia --project -e 'using Pkg; Pkg.update("<dependency>")'
julia --project -e 'using Pkg; Pkg.status("<dependency>")'
```

If the resolver did not select the new version, stop and report: another `[compat]` entry or an indirect dependency is constraining it, and guessing at fixes hides the real conflict.

## 4. Fix breakage

Use one session for the whole loop:
```
juliaclient --project --session=compat-<dependency> --revise=yes -e 'using TestEnv; TestEnv.activate(); include("test/runtests.jl")'
```

Diagnose failures and edit `src/`; Revise applies the edits, so re-running `include("test/runtests.jl")` in the same session picks them up without recompiling the package. If results look stale, restart only this session's worker (see `juliaclient`). Read the dependency's release notes or changelog for the breaking version when the cause is not obvious from the error.

## 5. Confirm and commit

Run the fresh-process test command from step 1 once more; the persistent session can mask ordering or stale-state problems that a clean process exposes.

Commit (see `git-commits`) the compat bump and any fixes together, with a message that names the dependency and the version range now allowed.

<!-- Adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
