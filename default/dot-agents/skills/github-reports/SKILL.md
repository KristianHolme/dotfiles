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
