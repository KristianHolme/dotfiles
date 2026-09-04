---
name: git-pull-requests
description: >-
  Create and manage GitHub pull requests with gh. Use when the user asks to open
  a PR, create a pull request, or push a branch for review.
---

# GitHub pull requests

Use `gh` for all GitHub PR tasks. Never update git config. Do not push unless needed for the PR and the user asked for a PR (push is implied by creating a PR from a local-only branch).

## Preflight (parallel)

1. `git status` — untracked / dirty state
2. `git diff` — staged and unstaged
3. Check whether the branch tracks a remote and is up to date
4. `git log` and `git diff [base]...HEAD` — full commit history since diverging from base

## Analyze

Review **all** commits that will be in the PR (not only the latest). Draft summary from the full set.

## Create

Sequentially:

1. Create branch if needed
2. Push with `-u` if needed
3. Create PR:

```bash
gh pr create --title "the pr title" --body "$(cat <<'EOF'
## Summary
<1-3 bullet points>

## Test plan
- [ ] ...

EOF
)"
```

Return the PR URL when done.

## Safety

- NEVER force-push to main/master; warn if asked
- NEVER skip hooks unless explicitly requested
- Prefer existing `github-cli` skill for other `gh` operations
