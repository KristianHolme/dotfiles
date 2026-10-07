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

Review every commit that will be in the PR.
The latest commit is not enough.

## Create

Do these steps in order:

1. Create the branch if needed.
2. Push with `-u` if needed.
3. Draft the title and the body with the [suggest-pr](../suggest-pr/SKILL.md) skill.
   Use the markdown file it writes.
   The first heading is the title.
   The remainder of the file is the body.
4. Create the PR with `gh pr create --title` and `--body-file`.
   Pass the body only. Leave the title heading out of the body.
5. Return the PR URL.

## Safety

- NEVER force-push to main/master; warn if asked
- NEVER skip hooks unless explicitly requested
- Prefer existing `github-cli` skill for other `gh` operations
