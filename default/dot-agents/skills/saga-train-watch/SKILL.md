---
name: saga-train-watch
description: >-
  Launch and babysit DRL_Sphere Slurm training on Saga (train_distributed.sh,
  a100, ntfy, /loop). Use when the user asks to start, monitor, relaunch, or
  watch a training experiment, train_distributed, Slurm array trials, or
  "/loop" check-ins for DRL_Sphere runs.
---

# Saga train watch (DRL_Sphere)

Launch a numbered training config, arm a 30m `/loop`, fix/relaunch minor
failures, ntfy on notable events, stop when all trials have results.

Project: `/cluster/projects/nn9886k/kholme/Code/DRL_Sphere`  
Cluster: Saga (`saga.sigma2.no`), account `nn9886k`, partition **`a100`**.

## Launch

```bash
cd /cluster/projects/nn9886k/kholme/Code/DRL_Sphere
CODE_DIR=/cluster/projects/nn9886k/kholme/Code SLURM_ACCOUNT=nn9886k PARTITION=a100 \
  scripts/train_distributed.sh <EXPERIMENT> --trials 1-N -- --mem=128G --time=<HH:MM:00>
```

- Config: `scripts/training_run_configs/<EXPERIMENT>.jl`
- Always pass **`--trials 1-N`** (count from seeds × variants in the config). Login-node
  `list_trial_ids.jl` uses `--compiled-modules=no` and often hangs / fails without CUDA.
- Prefer **`a100`**.
- Extra sbatch flags after `--` override script defaults (last wins), including `--time`.
- Prep (1 GPU) writes shared flow snapshots + force baselines; array waits on
  `afterok:<prep_id>`. Same Biot/Turek domain as a prior run → prep is usually fast.
- Relaunch after prep already OK: add `--no-prep`.

### Walltime

Size from a comparable finished run (`sacct` Elapsed), scale by `max_steps` ratio,
add margin for denser `num_snapshots` / eval:

| Situation | Rule of thumb |
|-----------|----------------|
| Same budget as last run | ~1.5–2× observed elapsed |
| N× steps | N× elapsed, then ~1.5–2× |
| Already submitted too high | `scontrol update JobId=<array> TimeLimit=HH:MM:00` |

Bake the same `--time=` into the watch-loop relaunch command.

## Watch loop (`/loop` every 30m)

Follow the Cursor **loop** skill (local monitored shell). Sentinel:
`AGENT_LOOP_TICK_<N>` (e.g. `AGENT_LOOP_TICK_27`).

```bash
while true; do
  sleep 1800
  echo 'AGENT_LOOP_TICK_<N> {"prompt":"<check prompt>"}'
done
```

Start with `notify_on_output` on `^AGENT_LOOP_TICK_<N>`, smoke-check PID + child
`sleep 1800`, run one status check immediately (do not wait for the first tick).

**Do not** `pkill -f 'AGENT_LOOP_TICK_…'` from a shell whose own cmdline contains
that string — it kills itself. Kill by tracked PID / children only.

### Tick checklist

1. `squeue -u $USER` for prep + array tasks
2. `sacct -j <array> --format=JobID,State,ExitCode,Elapsed` (skip `.batch`/`.exte`)
3. Count `data/experiments/<EXPERIMENT>/results/**/result_*.jld2`
4. Per trial log `slurm_logs/<EXPERIMENT>/<array>_c<id>_err`: last
   `Training... N%`, and any `ERROR|ArgumentError|UndefVar|LoadError`
5. Brief status to the user (done / running % / pending reason)

### Failures

| Kind | Action |
|------|--------|
| Minor (code/env, clear fix) | Fix, relaunch failed ids with `--trials <ids> --no-prep -- --mem=128G --time=<same>`, short **ntfy** of cause |
| Major / unclear (quota, account, widespread) | **ntfy**, stop auto-relaunch |
| Long queue only (`Priority`/`Resources`) | Report; ntfy once if stuck many hours; do not cancel |

Relaunch template:

```bash
CODE_DIR=/cluster/projects/nn9886k/kholme/Code SLURM_ACCOUNT=nn9886k PARTITION=a100 \
  scripts/train_distributed.sh <EXPERIMENT> --trials <ids> --no-prep -- --mem=128G --time=<HH:MM:00>
```

### Done

When all expected trials are `COMPLETED` and result `.jld2` count matches:

1. ntfy completion
2. Kill loop PID (+ children); `AwaitShell` so the completion notification is consumed
3. Confirm queue empty of that experiment

## ntfy

```bash
topic=$(cat .secrets/NTFY_TOPIC)
curl -sS -H "Title: <short>" -d "<one-line body>" "https://ntfy.sh/$topic"
```

Send on: start, completion, minor failure+relaunch, major problem, optionally long queue.

## Status one-liners

```bash
squeue -u $USER -o '%.18i %.12P %.8T %.10M %.9l %R'
sacct -j <JOBID> --format=JobID%16,State,ExitCode,Elapsed -n | grep -v '\.batch\|\.exte'
find data/experiments/<EXPERIMENT>/results -name 'result_*.jld2' | wc -l
```

Login-node `using DRL_Sphere` may fail CUDA precompile — expected. GPU jobs are the check.

## Project notes

Repo conventions live in `AGENTS.md` (CuArray, Float32, filename length, Saga paths).
Do not edit `Project.toml` without asking; use `Pkg` if deps must change.
