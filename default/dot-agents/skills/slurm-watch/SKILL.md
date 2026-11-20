---
name: slurm-watch
description: >-
  Launch and monitor Slurm GPU jobs on Saga, Olivia or Fox: submit, watch the
  start closely, fix clear failures, notify. Use for training runs, job
  arrays, relaunches, and watch check-ins.
---

# Slurm job watch

Submit, watch the start closely, then check at longer intervals. Fix clear
failures, notify the user when something is wrong, and stop when every
expected task has a result.

The project's `AGENTS.md` (Slurm section) gives the launch command and its
environment variables, the expected task IDs, the result and log paths, the
errors to look for, and what counts as done. If it gives none, ask the user.

## Submit

Submit the same tasks on all three clusters, Olivia first, unless the user
names clusters. On each cluster:

- `git pull` the checkout to `origin/main`.
- Set account and partition explicitly: wrapper defaults may belong to another
  cluster.
- Time limit: about 1.5× the run time of a comparable run on that GPU type
  (`sacct` elapsed). Short jobs start earlier through backfill.
- `--mem`: from a run on that cluster. The same job needs about twice the host
  RAM on Olivia.
- GPUs: `--gpus-per-node=<n>`. With `--gpus=<n>`, Fox and Olivia can start the
  job on fewer GPUs.

| Cluster | Account | Project area | GPU partition | Notes |
|---------|---------|--------------|---------------|-------|
| Olivia | `nn9886k` | `/cluster/projects/nn9886k/kholme` | `accel` (GH200, aarch64; about 2× an A100) | Only `accel` works, so Slurm failure-notify jobs fail to submit; the watch sends those notices. GPUs are `Exclusive_Process`: keep MPS on for several processes per GPU. |
| Saga | `nn9886k` | `/cluster/projects/nn9886k/kholme` | `a100` (A100 80 GB, AMD hosts) | Notify partition `normal`. |
| Fox | `ec12` | `/fp/projects01/ec12/ec-kholme` | `accel` (mixed GPU types) | The 10 TB project disk has been full: check free space first. |

Write the watch state to a file in the project's git-ignored output folder:
per cluster the job IDs, account, partition, resource flags, expected task
IDs, result and log paths. Update it when jobs change.

**Race:** when a copy of a task starts, cancel a pending copy on another
cluster only when that copy, started now, could not finish first. Take a
copy's expected run time as its time limit / 1.5. Example: a 4 h A100 job
leaves a pending Olivia copy queued until the A100 job has run about 2 h.
Cancel per task, not per array, and check that one copy of a task runs.

## Watch

**Start-up, close:** check each task every 2 minutes from its start until it
passes all three:

1. `sacct -X --format=JobID,State,AllocTRES` shows it running with the GPUs
   requested.
2. Its log shows the environment loaded with no error.
3. Its log shows the first progress line.

**After a good start:** arm one recurring check every 30 minutes before you
reply, and tell the user what runs and when it stops. In Claude Code use
`CronCreate` (fetch with ToolSearch) at an off-minute such as `7,37 * * * *`,
with a prompt that names the state file. Elsewhere use the harness's
scheduler; with none, say that monitoring ends with the session. Do not poll
a cluster more often than every 30 s.

At each check:

- Job states (`squeue`, `sacct`), result files against the expected task IDs,
  and the latest log lines of each running task.
- Apply the race rule.
- Once a task gives a measured run time, shorten the limit of pending tasks to
  about 1.5× that time: `scontrol update JobId=<array>_<task> TimeLimit=…`,
  one pending task at a time. An update on the bare array ID also shortens the
  running tasks, and a limit cannot be extended.
- Report done, running, failed and pending tasks, with percent done and
  expected finish.

## Failures

- Clear cause (out of memory, time limit, missing package or precompile
  error, bad path, too few GPUs): fix it, relaunch only the failed task IDs
  with the recorded flags, and notify with the cause and the new job IDs.
- Unclear or widespread failure: notify and stop automatic relaunch.
- A long queue is not a failure. Notify once if it lasts many hours.

To cancel a pending job that others depend on, first clear the dependants
(`scontrol update jobid=<id> Dependency=`), check it took, then `scancel`.
The other order cancels the dependants (`DependencyNeverSatisfied`). Cancel
its `afternotok` notify job too.

## Notify

When `.secrets/NTFY_TOPIC` exists in the checkout, send a one-line notice for
a failure, a relaunch, and completion:

```bash
curl -sS -H "Title: <short>" -d "<one-line body>" "https://ntfy.sh/$(cat .secrets/NTFY_TOPIC)"
```

Done when every expected task has its result. Notify, stop the recurring
check, and confirm no copy of the run remains queued on any cluster.
