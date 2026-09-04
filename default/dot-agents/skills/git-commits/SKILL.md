---
name: git-commits
description: >-
  Create git commits using repository conventions and safety rules. Use when the
  user asks to commit, create a commit, or stage and commit changes.
---

# Git commits

Only create commits when the user explicitly asks. If unclear, ask first.

## Safety

- NEVER update git config
- NEVER run destructive/irreversible git commands (`push --force`, hard reset, etc.) unless the user explicitly requests them
- NEVER skip hooks (`--no-verify`, `--no-gpg-sign`, etc.) unless explicitly requested
- NEVER force-push to main/master; warn if asked
- Avoid `git commit --amend` unless ALL hold:
  1. User explicitly requested amend, OR commit succeeded but a hook modified files that must be included
  2. HEAD commit was created by you in this conversation (`git log -1 --format='%an %ae'`)
  3. Commit has NOT been pushed (`git status` shows branch ahead)
- If commit FAILED or was REJECTED by a hook: NEVER amend — fix and create a NEW commit
- If already pushed: NEVER amend unless user explicitly requests it (implies force push)
- NEVER use interactive git flags (`-i`, `rebase -i`, `add -i`)
- Do not commit secrets (`.env`, `credentials.json`, …); warn if asked to
- Do not create empty commits when there is nothing to commit
- Do not push unless the user explicitly asks

## Workflow

Run in parallel:

1. `git status` (staged, unstaged, untracked)
2. `git diff` (staged and unstaged)
3. `git log` (recent messages — match style)

Then:

1. Draft a concise 1–2 sentence message focused on **why** (feat/fix/update accurately)
2. Stage relevant files
3. Commit with HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
Commit message here.

EOF
)"
```

4. `git status` to verify
