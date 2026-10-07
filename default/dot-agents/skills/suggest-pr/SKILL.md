---
name: suggest-pr
description: >-
  PR body for the current branch. Use when the user asks to suggest a PR description.
---

# suggest-pr

Write the PR body for the current branch into a draft file, then stop.
Open or push the PR only when the user asks.

## 1. Read the repo's PR rules

Search these paths:

- `CONTRIBUTING.md`, `docs/CONTRIBUTING.md`, `.github/CONTRIBUTING.md`
- `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/PULL_REQUEST_TEMPLATE/` (any `.md` file inside)
- `docs/pull_request_template.md`

When several templates exist, use the one for the changed area.
A bugfix uses the bugfix template. A feature uses the feature template.

Done when you have named the template file you will follow, or you have confirmed that none of these paths exist.

## 2. Read the branch

Run `git status`, `git diff` (staged and unstaged), `git log` for the current branch, and `git diff <base>...HEAD`.
`<base>` is `main` or `master`, or the branch this one tracks.

Done when you can state why the change exists, name its kind, and account for every commit in that range.
The kind is feature, fix, refactor, docs, or the repo's own kind.

## 3. Write the title and the body

Write the body in STE-flavored English, per [asd-ste100](../asd-ste100/SKILL.md).
Keep a fact, a number, or a domain term when a shorter sentence would drop it.

The title is one line, imperative, in the commit style of the guidelines and recent `git log`.

Keep the template's headings and their order.
Put the sketch, the breaking sentence, and the who-can-hit-it sentence in the summary section.
Put tests, benchmarks, and before and after in the section that asks for tests or evidence.
When that section is absent, put them in the summary section.
Put implementation background in the template section for details or implementation notes.
When the template has no such section, add `## Details` after the evidence section.

When no template exists, use this shape:

```markdown
## Summary

<smallest show-me sketch that makes the change clear>

<Breaking or not. One sentence.>

<Who can hit the change. One sentence.>

## Evidence

- **Tests:** <passed, failed, or not run. Name the test set when you know it.>
- **Benchmarks:** <key before and after numbers, only when results exist>
- **Before:** <screenshot, command output, or failing test>
- **After:** <screenshot, command output, or passing test>

## Details

<implementation background the summary and the evidence do not carry>

<signature line>
```

### Summary

The sketch follows [show-me](../show-me/SKILL.md).

**Breaking.** A caller that works today must change, or a public result changes.
Not breaking: existing callers keep the same result.

**Who can hit it.** Pick one.

- **Low-level internal.** Only code inside the package hits it.
- **Mid-level internal.** A user hits it only by calling an internal name outside the public API.
- **User-facing.** A user of the public API can hit it.

For Julia, the public API is the exported and documented interface.
A low-level internal is an unexported helper that only the package calls.
A mid-level internal is an unexported name a user can call by reaching into the package.

Write both as plain sentences.
"This change is not breaking."
"Only low-level internals change. A public caller does not hit this."

### Evidence

Issue links, PR links, screenshots, and large tables follow [github-reports](../github-reports/SKILL.md).
Write links in the prose, outside the sketch.
A screenshot is a `![PLACEHOLDER: path]` line.
A large table is a collapsed `<details>` block.

**Tests.** Read a local test run or CI.
Write passed, failed, or not run, and name the test set when you know it.
A pass or a fail comes from output you have. With no run and no CI result, write not run.

**Benchmarks.** Copy numbers from results that already exist.
Look in BenchmarkTools output, Chairmarks output, AirspeedVelocity output, CI logs, and result files in the branch.
The Benchmarks line carries the key numbers.
With no results, omit the Benchmarks line.
Run a benchmark only when the user asks.

### Details

Details follows Evidence.
It holds implementation background: the approach, the structure of the change, and follow-ups.
A longer sketch belongs here when the summary sketch is too small for the implementation.
Leave out anything the summary or the evidence already says.

### Signature

The signature is the last line of the body, with no heading.

- Cursor: `Made with Cursor`
- Claude Code: `Generated with Claude Code`
- Another tool: `Generated with <tool name>`

Done when all of these are true:

- The title is one imperative line in the repo's commit style.
- The summary has a show-me sketch, one breaking sentence, and one who-can-hit-it sentence.
- Evidence has a Tests line and a before and after. It has a Benchmarks line when results exist.
- Details follows Evidence and adds the approach, the structure, or follow-ups.
- The body meets every extra requirement from the guidelines in step 1, such as a linked issue, a breaking-change note, or a screenshot.
- The signature is the last line.

## 4. Save the draft file

The file is markdown.
Line 1 is a level-1 heading with the title.
A blank line follows.
The body follows that blank line.

Search the repo root, then one level down, for an existing directory named `notes`, `scratch`, `tmp`, or `.scratch`.
Use the first directory where `git check-ignore` ignores the draft file.
When git tracks the parent, the draft file itself is still ignored.
When no such directory exists, ask the user for a path that `git check-ignore` ignores.

Name the file `pr-<branch>.md`.
Replace each `/` in the branch name with `-`.
When that file already exists, replace it.

Done when `git check-ignore` accepts the path and the file starts with the title heading.
The chat message is the file path, the title, and, when you replaced a file, that you replaced it.
The body stays in the file.
