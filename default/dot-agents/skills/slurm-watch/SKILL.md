---
name: slurm-watch
description: >-
  Launch and monitor Slurm GPU jobs on Saga or Olivia: choose the cluster,
  size resources, arm a recurring watch, retry clear failures, and send
  notifications. Use for training runs, job arrays, relaunches, and watch
  check-ins.
---

# Slurm job watch

Launch a job or job array on the user's chosen Slurm cluster. Monitor it, fix
clear failures, notify on notable events, and stop when every expected task
has a result.

## Project details

Read the project's `AGENTS.md` (Slurm or cluster section) in the checkout on
the cluster. Get from it:

- the launch command or wrapper, and its required environment variables;
- how to determine the expected task or trial IDs;
- where results and logs go, and which errors to look for;
- what counts as done.

If the project gives none of these, ask the user before you submit.

## Resolve the target before submission

1. Use the cluster the user named; otherwise the cluster of the active login
   session; ask if several remain plausible. Saga and Olivia use the same
   project paths, so a checkout path does not identify the cluster. Run all
   submission and status commands on the chosen cluster.
2. Check the Slurm account and partitions (`sinfo`, local configuration).
   Select a GPU partition that supports the job's GPU request and, if the
   project uses failure-notification jobs, a short CPU partition for them.
   Set account and partitions explicitly: wrapper defaults may belong to
   another cluster.
3. Size memory and walltime for the job and the cluster limits. Estimate
   walltime from a comparable completed run (`sacct` elapsed), scale by the
   amount of work, and add time for checkpoints and evaluation. Record the
   settings and job IDs for later checks and retries. Check cluster limits
   before `scontrol update` of a time limit.

Known values, to verify on the target:

| Cluster | GPU partition | Notification partition |
|---------|---------------|------------------------|
| Saga | `a100` (A100 80 GB, AMD hosts) | `normal` |
| Olivia | `accel` (GH200, aarch64) | none (see below) |

Both use account `nn9886k` and project area `/cluster/projects/nn9886k/kholme`.
On Olivia, check the job's Julia and depot setup for aarch64.

**Olivia:** only `accel` is usable; submitting to `small` fails with
`AssocGrpBillingMinutes`, so Slurm failure-notification jobs cannot be created
(main jobs still go through). The watcher must cover this: check job states
with `sacct` every tick, send the ntfy failure notice itself for any
FAILED/TIMEOUT/CANCELLED/OUT_OF_MEMORY job, and use a recurring cron (e.g.
`7,37 * * * *`) rather than Slurm-triggered notices.

**Olivia MPS:** GPUs are in `Exclusive_Process` mode, so several processes per
GPU only work through an MPS daemon. Do not disable MPS for multi-process GPU
jobs (in Julia, workers after the first fail at setup with a misleading
`MethodError ... ::RemoteException`).

## Watch

Arming the recurring check is part of the launch. Before replying after
submission, arm a check every 30 minutes with the harness's scheduler and tell
the user which mechanism runs and when it stops. Make the check prompt
self-contained: job IDs, cluster, account, partitions, resource flags, expected
task IDs, result and log paths.

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

Run the first status check immediately, then every tick. Do not poll Slurm more
often than every 30 s. At each check, on the target cluster:

1. `squeue -u "$USER"` for the job and its array tasks.
2. `sacct -j <job-id> --format=JobID,State,ExitCode,Elapsed` for final states;
   ignore `.batch` and `.extern`.
3. Match result files to the expected task IDs.
4. Read the latest lines of each running task's log for progress and errors.
   Julia `@info` and warnings go to stderr, so the `.err` file is not only
   errors.
5. Report completed, running, failed, and pending tasks with queue reasons.

For a clear code or environment failure, fix the cause and relaunch only the
failed IDs with the recorded settings; notify with the cause and new job IDs.
For an unclear or widespread failure, notify and stop automatic relaunch. A
long queue is not a failure: report the reason, and notify once if it persists
for many hours.

Done when every expected task succeeded and has its result. Notify completion,
stop the recurring check, and confirm no jobs for the run remain queued.

## Notifications

When `.secrets/NTFY_TOPIC` exists in the checkout, send start, completion,
failure, and relaunch notices with concise run and cluster details:

```bash
topic=$(cat .secrets/NTFY_TOPIC)
curl -sS -H "Title: <short>" -d "<one-line body>" "https://ntfy.sh/$topic"
```

If the project's wrapper also creates Slurm failure-notification jobs, verify
they were accepted.
