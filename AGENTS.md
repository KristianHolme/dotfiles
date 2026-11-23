# Agent notes

- Global agent instructions: edit `default/dot-agents/AGENTS.md` (general) or
  the machine's `~/.agents/AGENTS.local.md` (machine-specific, not in this repo),
  then run `install_agent_instructions` from `bin/lib-dotfiles.sh` (or `dar`/`dac`).
  The files under `~/.claude`, `~/.codex`, `~/.pi`, `~/.gemini/GEMINI.md` and
  `~/.cursor/rules` are generated. Skills are symlinked per skill into
  `~/.claude/skills` and `~/.gemini/config/skills` (Antigravity CLI).

- The setup scripts copy skills into `~/.codex/skills` because Codex does not
  currently read skills through the symlinks in `~/.agents`. This workaround
  can be removed when Codex correctly reads those symlinked skills.
- When diagnosing SSH master reuse (Fain's ssh:// hosts, theme sync), check `ssh -O check <host>`. Ghostty can
  give an interactive `ssh <host>` a temporary ControlPath; use
  `bin/dotfiles-ssh-login.sh <host>` to create the configured ControlMaster.
