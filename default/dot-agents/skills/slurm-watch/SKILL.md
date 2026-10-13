---
name: slurm-watch
description: >-
  Launch and monitor DRL_Sphere Slurm training on the chosen cluster, including
  Saga and Olivia. Use for training runs, trial arrays, relaunches, and watch
  check-ins.
---

# DRL_Sphere train watch

Launch a numbered training config on the user's chosen Slurm cluster. Monitor
prep and trial jobs, fix clear failures, notify on notable events, and stop
when every expected trial has a result.

## Resolve the target before submission

1. Use the cluster named by the user. Otherwise, use the cluster of the active
   login session; ask if several targets remain plausible. Saga and Olivia
   share home and project paths, so a checkout path does not identify the
   cluster. Run all submission and status commands on the chosen cluster.
2. In that checkout, read `AGENTS.md` and `scripts/train_distributed.sh`.
   Resolve `CODE_DIR` from the checkout parent. Check the config at
   `scripts/training_run_configs/<EXPERIMENT>.jl` and determine the trial IDs.
3. Check the active Slurm account and partitions with `sinfo` and local
   configuration. Select a GPU partition that supports the wrapper's GPU
   request, plus a short CPU partition for its failure-notification jobs.
   Set `SLURM_ACCOUNT`, `PARTITION`, and `NOTIFY_PARTITION` explicitly: the
   wrapper's defaults may belong to a different cluster.
4. Size memory and walltime for the config and cluster limits. Inspect the
   wrapper's prep and array resource requests before submitting. Record the
   chosen settings and job IDs for subsequent checks and retries.

Current known examples, to verify on the target before use:

| Cluster | GPU partition | Notification partition |
|---------|---------------|------------------------|
| Saga | `a100` | `normal` |
| Olivia | `accel` | none (see below) |

**Olivia:** only the `accel` partition is usable; submitting to `small` fails with
`AssocGrpBillingMinutes`, so the wrapper's `failnotify` jobs cannot be created (expect
"fail-notify: submit failed"; the main jobs still go through). The watcher must cover
this: check job states with `sacct` at every tick, send the ntfy failure notice itself
for any FAILED/TIMEOUT/CANCELLED/OUT_OF_MEMORY job, and use a recurring cron
(`CronCreate`, e.g. `7,37 * * * *`) rather than relying on Slurm-triggered notices.

**Olivia MPS is mandatory:** GPUs are in `Exclusive_Process` compute mode, so several
sim workers per GPU only work through the MPS daemon. Never pass `MPS=0` (all workers
after the first fail at env setup with a misleading `MethodError ... ::RemoteException`).

Both currently use account `nn9886k` and a checkout under
`/cluster/projects/nn9886k/kholme/Code/DRL_Sphere`. Olivia's GPU nodes are
aarch64; check the current job wrapper for its Julia and depot setup.

## Launch

From the chosen checkout:

```bash
CODE_DIR="$(dirname "$PWD")" SLURM_ACCOUNT=<account> PARTITION=<gpu-partition> \
  NOTIFY_PARTITION=<cpu-partition> \
  scripts/train_distributed.sh <EXPERIMENT> --trials <ids> -- --mem=<memory> --time=<HH:MM:SS>
```

- Pass explicit trial IDs or a range when listing them on the login node fails.
  `list_trial_ids.jl` may hang or fail there when CUDA is unavailable. Confirm
  IDs from the config; do not assume every config uses `1-N`.
- Extra `sbatch` flags after `--` override the wrapper's defaults. They apply
  to both prep and array submissions; choose values valid for both.
- The one-GPU prep writes shared flow snapshots and force baselines. Array
  tasks depend on successful prep. Use `--no-prep` on a retry only after the
  required assets are available.

Estimate walltime from a comparable completed run (`sacct` elapsed), scale by
the step count, then allow for snapshots and evaluation. Keep the chosen
resource flags with the run so retries use the same settings. Check cluster
limits before changing a submitted job's time limit with `scontrol update`.

## Watch

Scheduling the recurring check is part of the launch, not optional. Before
replying to the user after submission, arm a check every 30 minutes with
whatever scheduler the harness provides, and tell the user which mechanism is
running and when it stops. Make the check prompt self-contained: job IDs,
cluster, account, partitions, resource flags, and the expected trial IDs.

Pick the mechanism by harness:

- Claude Code: load `CronCreate` (deferred; fetch with ToolSearch) and
  schedule a recurring job at an off-minute such as `7,37 * * * *`. Session
  only, expires after 7 days. `ScheduleWakeup` is only for `/loop`.
- Any harness with a monitored `/loop`: follow its skill and arm it with a
  unique `AGENT_LOOP_TICK_<N>` sentinel. Smoke-check the process and its
  child sleep, then run the first status check immediately. Track the loop PID
  and children so they can be stopped on completion.
- Other harnesses (Cursor, Codex, pi, ...): use its native scheduler or
  background-task facility if one exists.
- No scheduler at all: poll for the duration of the active session and tell
  the user plainly that monitoring ends when the session does. Use this only
  after confirming nothing above is available.

Run the first status check immediately, then on each tick.

At each check, on the target cluster:

1. `squeue -u "$USER"` for prep and array tasks.
2. `sacct -j <job-id> --format=JobID,State,ExitCode,Elapsed` for their final
   states; ignore `.batch` and `.extern` steps.
3. Count `data/experiments/<EXPERIMENT>/results/**/result_*.jld2` and match
   files to the expected trial IDs.
4. Read `slurm_logs/<EXPERIMENT>/<array>_c<id>_err` for the latest training
   percentage and errors such as `ArgumentError`, `UndefVarError`, or
   `LoadError`. Check prep logs when its job fails.
5. Report completed, running, failed, and pending trials with the queue reason.

For a clear code or environment failure, fix the cause and relaunch only
failed IDs with the recorded cluster settings and resource flags. Notify with
the cause and new job IDs. For an unclear or widespread failure, notify and
stop automatic relaunch. A long queue is not a failure: report its reason and
notify once if it persists for many hours.

```bash
CODE_DIR="$(dirname "$PWD")" SLURM_ACCOUNT=<account> PARTITION=<gpu-partition> \
  NOTIFY_PARTITION=<cpu-partition> \
  scripts/train_distributed.sh <EXPERIMENT> --trials <failed-ids> --no-prep -- \
  --mem=<memory> --time=<HH:MM:SS>
```

The run is done when every expected trial has completed successfully and has
its result file. Notify completion, stop the recurring check, and confirm no
jobs for the experiment remain in the queue.

## Notifications

When `.secrets/NTFY_TOPIC` exists in the checkout, send start, completion,
failure, and relaunch notices with concise run and cluster details:

```bash
topic=$(cat .secrets/NTFY_TOPIC)
curl -sS -H "Title: <short>" -d "<one-line body>" "https://ntfy.sh/$topic"
```

The submission wrapper also creates Slurm failure-notification jobs using
`NOTIFY_PARTITION`; verify those jobs were accepted.
