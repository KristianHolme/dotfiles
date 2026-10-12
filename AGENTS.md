# Agent notes

- The setup scripts copy skills into `~/.codex/skills` because Codex does not
  currently read skills through the symlinks in `~/.agents`. This workaround
  can be removed when Codex correctly reads those symlinked skills.
- When diagnosing Herdr SSH reuse, check `ssh -O check <host>`. Ghostty can
  give an interactive `ssh <host>` a temporary ControlPath; use
  `bin/dotfiles-ssh-login.sh <host>` to create the configured ControlMaster.
