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

1. Use the cluster the user named; otherwise the cluster of the active login
   session; ask if several remain plausible. Saga and Olivia share home and
   project paths, so a checkout path does not identify the cluster. Run all
   submission and status commands on the chosen cluster.
2. In that checkout, read `AGENTS.md` and `scripts/train_distributed.sh`.
   Resolve `CODE_DIR` from the checkout parent. Check
   `scripts/training_run_configs/<EXPERIMENT>.jl` and determine the trial IDs.
3. Check the Slurm account and partitions (`sinfo`, local configuration).
   Select a GPU partition that supports the wrapper's GPU request and a short
   CPU partition for failure-notification jobs. Set `SLURM_ACCOUNT`,
   `PARTITION`, and `NOTIFY_PARTITION` explicitly: the wrapper's defaults may
   belong to another cluster.
4. Size memory and walltime for the config and cluster limits, after inspecting
   the wrapper's prep and array resource requests. Record settings and job IDs
   for later checks and retries.

Known examples, to verify on the target:

| Cluster | GPU partition | Notification partition |
|---------|---------------|------------------------|
| Saga | `a100` | `normal` |
| Olivia | `accel` | none (see below) |

Both use account `nn9886k` and a checkout under
`/cluster/projects/nn9886k/kholme/Code/DRL_Sphere`. Olivia's GPU nodes are
aarch64; check the wrapper's Julia and depot setup.

**Olivia:** only `accel` is usable; submitting to `small` fails with
`AssocGrpBillingMinutes`, so the wrapper's `failnotify` jobs cannot be created
("fail-notify: submit failed"; main jobs still go through). The watcher must
cover this: check job states with `sacct` every tick, send the ntfy failure
notice itself for any FAILED/TIMEOUT/CANCELLED/OUT_OF_MEMORY job, and use a
recurring cron (e.g. `7,37 * * * *`) rather than Slurm-triggered notices.

**Olivia MPS is mandatory:** GPUs are in `Exclusive_Process` mode, so several
sim workers per GPU only work through the MPS daemon. Never pass `MPS=0` (all
workers after the first fail at env setup with a misleading `MethodError ...
::RemoteException`).

## Launch

From the chosen checkout:

```bash
CODE_DIR="$(dirname "$PWD")" SLURM_ACCOUNT=<account> PARTITION=<gpu-partition> \
  NOTIFY_PARTITION=<cpu-partition> \
  scripts/train_distributed.sh <EXPERIMENT> --trials <ids> -- --mem=<memory> --time=<HH:MM:SS>
```

- Pass explicit trial IDs or a range when listing on the login node fails
  (`list_trial_ids.jl` may hang without CUDA). Confirm IDs from the config; not
  every config uses `1-N`.
- Flags after `--` override the wrapper's defaults for both prep and array
  submissions; choose values valid for both.
- The one-GPU prep writes shared flow snapshots and force baselines; array
  tasks depend on its success. Use `--no-prep` on a retry only after the assets
  exist.

Estimate walltime from a comparable completed run (`sacct` elapsed), scale by
step count, add time for snapshots and evaluation. Keep the resource flags with
the run so retries match. Check cluster limits before `scontrol update` of a
time limit.

## Watch

Arming the recurring check is part of the launch. Before replying after
submission, arm a check every 30 minutes with the harness's scheduler and tell
the user which mechanism runs and when it stops. Make the check prompt
self-contained: job IDs, cluster, account, partitions, resource flags, expected
trial IDs.

- Claude Code: load `CronCreate` (deferred; fetch with ToolSearch) and schedule
  a recurring job at an off-minute such as `7,37 * * * *`. Session only,
  expires after 7 days. `ScheduleWakeup` is only for `/loop`.
- Harness with a monitored `/loop`: follow its skill, arm it with a unique
  `AGENT_LOOP_TICK_<N>` sentinel, smoke-check the process and child sleep, and
  track the loop PID and children to stop them on completion.
- Other harnesses (Cursor, Codex, pi, ...): use the native scheduler or
  background-task facility.
- No scheduler: poll during the active session and say plainly that monitoring
  ends with it. Use only after confirming nothing above exists.

Run the first status check immediately, then every tick. At each check, on the
target cluster:

1. `squeue -u "$USER"` for prep and array tasks.
2. `sacct -j <job-id> --format=JobID,State,ExitCode,Elapsed` for final states;
   ignore `.batch` and `.extern`.
3. Count `data/experiments/<EXPERIMENT>/results/**/result_*.jld2` and match
   them to the expected trial IDs.
4. Read `slurm_logs/<EXPERIMENT>/<array>_c<id>_err` for the latest training
   percentage and errors (`ArgumentError`, `UndefVarError`, `LoadError`). Check
   prep logs if prep fails.
5. Report completed, running, failed, and pending trials with queue reasons.

For a clear code or environment failure, fix the cause and relaunch only the
failed IDs with the recorded settings; notify with the cause and new job IDs.
For an unclear or widespread failure, notify and stop automatic relaunch. A
long queue is not a failure: report the reason, and notify once if it persists
for many hours.

```bash
CODE_DIR="$(dirname "$PWD")" SLURM_ACCOUNT=<account> PARTITION=<gpu-partition> \
  NOTIFY_PARTITION=<cpu-partition> \
  scripts/train_distributed.sh <EXPERIMENT> --trials <failed-ids> --no-prep -- \
  --mem=<memory> --time=<HH:MM:SS>
```

Done when every expected trial succeeded and has its result file. Notify
completion, stop the recurring check, and confirm no jobs for the experiment
remain queued.

## Notifications

When `.secrets/NTFY_TOPIC` exists in the checkout, send start, completion,
failure, and relaunch notices with concise run and cluster details:

```bash
topic=$(cat .secrets/NTFY_TOPIC)
curl -sS -H "Title: <short>" -d "<one-line body>" "https://ntfy.sh/$topic"
```

The wrapper also creates Slurm failure-notification jobs using
`NOTIFY_PARTITION`; verify they were accepted.
