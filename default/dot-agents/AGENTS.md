# Global agent instructions

- Put files the user reads or watches (reports, drafts, logs, figures, run outputs) in a git-ignored folder in the working directory. Use the folder `.gitignore` already ignores (e.g. `_research/`), else add one to `.git/info/exclude`. Keep `/tmp` and session scratchpads for throwaway intermediates.
- A run expected to take more than about 2 minutes (simulation, training, video render, benchmark) must report progress to its log: steps done of total, elapsed time and ETA. When you report on it, give percent done and the expected finish time, not only "running".
- If in Claude Code: wait for a long run with `run_in_background` (it notifies on exit) or one Monitor with `timeout_ms: 1800000`. A `sleep N` before a read is blocked.
