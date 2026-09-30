---
name: github-reports
description: >-
  Write reports, summaries, and findings that will be posted on GitHub as PR
  descriptions, issue or PR comments, or similar. Use when drafting text for
  GitHub that references issues, PRs, or commits, or that contains large
  benchmark or result tables.
---

# GitHub reports

Text posted on GitHub is rendered as GitHub-flavored markdown. Write it so
references become links and long content does not bury the conclusion.

## Reference issues and PRs with full GitHub syntax

Always use the syntax GitHub auto-links, and never shorten a reference to
another repo.

| Target | Write | Never write |
| --- | --- | --- |
| Same repo | `#45` | `PR 45`, `issue 45` |
| Other repo, same owner | `repo#45` | `repo #45` |
| Other repo, other org | `other-org/other-repo#45` | `other-repo#45`, `other-repo #45`, `#45` |
| Commit, other repo | `other-org/other-repo@abc1234` | `other-repo commit abc1234` |

- `#45` always resolves to the repo where the comment is posted. Using it for
  a foreign PR or issue silently links to the wrong item.
- Use `owner/repo#N` in full whenever the target is not the current repo, even
  if it was already mentioned earlier in the text.
- Full URLs also work; GitHub shortens them to the same form when rendered.
- Do not put the reference inside backticks or code blocks. That disables
  auto-linking.
- Find the current repo with `gh repo view --json nameWithOwner` when unsure
  whether a reference is same-repo or foreign.

## Collapse large optional tables

Wrap large tables, such as in-depth benchmark results, that are not needed to
understand the conclusion in a collapsed `<details>` block. State the key
result in prose above it.

```markdown
Summary of the result in a sentence or two, with the key numbers inline.

<details><summary>Details</summary>
<p>

| benchmark | before | after |
| --- | --- | --- |
| ... | ... | ... |

</p>
</details>
```

- Keep the blank lines after `<p>` and before `</p>`. Without them GitHub does
  not render the markdown inside the block.
- Make the `<summary>` text specific when useful, for example
  `Full benchmark results`.
- Keep small tables (a handful of rows) and anything the reader must see to
  follow the argument outside the block.

## Placeholders for images and figures

An agent cannot upload images to a GitHub comment. Where a figure, plot,
screenshot, or other binary file belongs, insert a placeholder. The user
uploads the file (drag and drop into the GitHub editor) and replaces the
placeholder.

```markdown
![PLACEHOLDER: dev/reports/speedup_vs_size.png] Speedup against problem size; the crossover is at n = 512.
```

- Use the form `![PLACEHOLDER: <path>]`, where `<path>` is the repo-relative
  path of the file, normally under `dev/reports/`. Save or name the file at
  that path when it exists locally; otherwise give the path where it should be
  saved.
- Put a one-line caption after the placeholder that says what the figure shows
  and which conclusion it supports, so the report reads correctly before the
  image is uploaded.
- Use a descriptive snake_case file name. Use one placeholder per file.
- Refer to the figure in the surrounding prose. Do not rely on the image alone
  to carry a result; give the key numbers inline.
- List all placeholders to the user when handing over the draft, so none is
  posted unreplaced.
