# suggest-pr

Draft a pull request title and description for the current branch's changes.

## 1. Gather repo conventions

Read contributing guidelines and PR templates before writing anything. Search common locations:

- `CONTRIBUTING.md`, `docs/CONTRIBUTING.md`, `.github/CONTRIBUTING.md`
- `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/PULL_REQUEST_TEMPLATE/` (any `.md` files inside)
- `docs/pull_request_template.md`

If multiple templates exist, prefer the one that matches the changed area (e.g. bugfix vs feature) when the repo distinguishes them.

## 2. Understand the changes

Inspect what will go into the PR:

- `git status`
- `git diff` (staged and unstaged)
- `git log` on the current branch
- `git diff <base>...HEAD` where `<base>` is the default branch (`main` or `master`, or the branch this one tracks)

Summarize the nature of the changes (feature, fix, refactor, docs, etc.) and focus on **why**, not just **what**.

## 3. Draft title and description

- **Title**: concise, imperative mood, matches repo commit/PR style from contributing guidelines and recent `git log` messages.
- **Description**: follow the PR template exactly when one exists (keep its headings and section order). When no template exists, use:

```markdown
## Summary
<1-3 bullet points>

## Details
<relevant context, implementation notes, or follow-ups>
```

Also follow any extra requirements from contributing guidelines (linked issues, breaking changes, screenshots, etc.).

Do not create or push the PR unless the user asks.

## 4. Output format

Present the result as **two separate fenced code blocks** so the user can copy each part easily. Use a `text` fence (not `markdown`) so the content renders as raw copyable text.

**Title**

```text
<one-line PR title>
```

**Description**

```text
<full PR description body, including template headings>
```

Do not wrap the title or description in extra quotes or commentary inside the fences.
