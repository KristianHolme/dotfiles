---
name: github-cli
description: Execute GitHub CLI commands for repository operations. Use when creating or managing GitHub resources (repositories, issues, pull requests, releases, branches, teams), working with gh commands, or when the user mentions GitHub operations.
---

# GitHub CLI (gh)

Use `gh <command> --help` for flags; do not guess them.

- Pass `-R owner/repo` when not inside the target repo's checkout.
- Use `--json fields` (with `-q`/`jq`) when processing output.
- `--dry-run` exists only on some commands; check `--help` before relying on it.
- For creating or updating file contents, use git, or `gh api`, not `gh` porcelain commands.
- If a command fails, check `gh auth status`.
- Creating or merging PRs, releases, issues, and workflow runs changes shared state: do it only when asked.

## Library and package docs

Prefer `gh` over editor-only doc plugins when looking up libraries:

```bash
gh api repos/owner/repo/readme -q .content | base64 -d   # README
gh search code "Query" --repo owner/repo
```

Clone upstream source with `gh repo clone` when README examples are not enough.
