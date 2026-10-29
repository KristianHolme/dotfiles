# AirspeedVelocity CI (GitHub Actions)

PR comments (needs `pull_request_target` and `pull-requests: write`):

```yaml
name: Benchmark this PR
on:
  pull_request_target:
    branches: [master]
permissions:
  pull-requests: write
jobs:
  bench:
    runs-on: ubuntu-latest
    steps:
      - uses: MilesCranmer/AirspeedVelocity.jl@action-v1
        with:
          julia-version: '1'
          extra-pkgs: 'ExtraPkg1,ExtraPkg2'
```

Job summary instead: trigger on `pull_request` and add `job-summary: 'true'` under `with:`.

Action inputs mirror the CLI: `extra-pkgs` (-a), `script` (-s), `rev` (-r), `bench-on`, `filter` (-f), `exeflags` (-e), `tune`.

Several Julia versions: use a `strategy.matrix.julia: ['1', '1.10']` and pass `julia-version: ${{ matrix.julia }}`.
