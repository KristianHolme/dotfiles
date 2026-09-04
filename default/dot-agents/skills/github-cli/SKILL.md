---
name: github-cli
description: Execute GitHub CLI commands for repository operations. Use when creating or managing GitHub resources (repositories, issues, pull requests, releases, branches, teams), working with gh commands, or when the user mentions GitHub operations.
---

# GitHub CLI (gh)

## Quick Reference

### Common Commands

**Repositories:**
```bash
# Create a new repo
gh repo create <name> --public --description "..."

# View repo details
gh repo view owner/repo

# Clone a repo
gh repo clone owner/repo
```

**Pull Requests:**
```bash
# Create a PR
gh pr create --base main --title "..." --body "..."

# List PRs
gh pr list --state open

# View PR details
gh pr view <number>

# Checkout PR branch locally
gh pr checkout <number>

# Review and merge
gh pr merge <number> --squash
```

**Issues:**
```bash
# Create an issue
gh issue create --title "..." --body "..."

# List issues
gh issue list --label bug

# View issue
gh issue view <number>

# Close issue
gh issue close <number>
```

**Releases:**
```bash
# Create a release
gh release create <tag> --title "..." --notes "..."

# Upload assets
gh release upload <tag> ./file.tar.gz

# List releases
gh release list
```

**Workflows:**
```bash
# Trigger workflow
gh workflow run <workflow-file>

# View workflow runs
gh run list

# View logs
gh run view <run-id> --log
```

## Command Patterns

### Interactive Mode
Use `--web` flag to open browser instead of CLI:
```bash
gh pr create --web
gh issue create --web
```

### JSON Output
Use `--json` flag for programmatic output:
```bash
gh pr list --json number,title,author
gh repo list --json nameWithOwner,updatedAt
```

### Piping with jq
```bash
gh pr list --json number | jq '.[].number'
```

### Editing Files
For file operations (creating/updating), prefer GitHub API or git commands over gh CLI.

## Flags Reference

Common flags across commands:

| Flag | Purpose |
|------|---------|
| `-R, --repo <owner/repo>` | Target specific repo |
| `-b, --branch <branch>` | Specify branch |
| `--dry-run` | Preview changes without executing |
| `-w, --web` | Open in browser |
| `-y, --yes` | Skip confirmation prompts |
| `--json` | Output as JSON |

## Library and package docs

Prefer `gh` over editor-only doc plugins when looking up libraries (portable across agents):

```bash
gh repo view owner/repo --web          # docs / README in browser
gh api repos/owner/repo/readme -q .content   # raw README (base64)
gh search code "Query" --repo owner/repo
```

Clone or browse upstream source with `gh` / `git` when API examples in README are not enough.

## Best Practices

1. **Specify owner/repo explicitly** when not in a git repository context
2. **Use `--dry-run`** to verify commands before execution
3. **Add context** via `--body` or `--title` for PRs and issues
4. **Use JSON output** when processing results programmatically
5. **Check authentication** with `gh auth status` if commands fail

## Authentication

```bash
# Login to GitHub
gh auth login

# Check current status
gh auth status

# Switch accounts
gh auth switch
```

## Help

Use `gh <command> --help` for command-specific options:
```bash
gh pr create --help
gh release create --help
```
