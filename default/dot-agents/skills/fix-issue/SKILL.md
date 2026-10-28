---
name: fix-issue
description: Triage and resolve one item from a Julia package's issue tracker, ending in a code fix, a doc fix, or a reasoned "no change needed". Use when the user points at an issue number or link, says "look at issue N", or pastes an issue body and asks what to do about it.
disable-model-invocation: true
---

Run inside a package git repository. The user supplies an issue number or link
(for the `origin` repository); if missing, ask.

The goal is the **right** action: a code fix, a doc edit, or "no change
needed". Do not assume the issue is a bug. Reproduce first, decide second, act
third.

## 1. Gather context

- Read the whole thread in one structured call (resolve a link to its number
  first); `gh issue view XYZ --comments` can fold or truncate the body:

  ```bash
  gh issue view XYZ --json title,state,labels,body,comments \
    --jq '"# \(.title)  [\(.state)]\nLabels: \(.labels | map(.name) | join(", "))\n\n\(.body)\n\n=== \(.comments | length) comment(s) ===" + (.comments | map("\n\n--- \(.author.login) @ \(.createdAt) ---\n\(.body)") | join(""))'
  ```

  Note the reporter's Julia version, package version, OS, stack trace and
  reproducer.
- Read this session's conversation and any material it points to (linked
  issues/PRs, relevant source, docs).
- Look for an already-landed fix: `git log --oneline -20`, then
  `git log -S<symbol>` or `gh pr list --search XYZ`.

## 2. Reproduce with a MWE

Build a minimal working example of the reported behavior.

- Match the reporter's Julia version and the local `Project.toml`. Pin versions
  with juliaup channels (`julia +lts`, `+release`, `+1.x`); a bare `julia`
  uses the default channel, which can change.
- Iterate with `juliaclient --project --session=issue-XYZ --revise=yes` (see
  the `juliaclient` skill) so `src/` edits apply without recompiling.
  `juliaclient` uses the default channel; when the reporter's version matters,
  use `julia +<channel>`. Packages whose behavior depends on precompile/load
  state that Revise cannot hot-patch (Revise and its dependencies,
  SnoopCompile) need a fresh `julia` process for every attempt.
- If the MWE does **not** reproduce, that is a result. Do not paper over it
  with a speculative fix; it points to already fixed, reporter-error, or
  cannot replicate.

## 3. Decide

Pick one: **bug to fix** → 4a; **limitation to document** → 4b; **no package
change** (reporter-error, already fixed, blocked upstream, cannot replicate)
→ 4c.

## 4. Act

Before preparing a change (4a, 4b), do a narrow related-work check for this
fix only:

- `gh pr list --search "<keyword>"` and `gh issue list --search "<keyword>"`.
- If an open PR already fixes it, stop and report that. If several open issues
  share the root cause, widen the fix and tests to cover them and list their
  numbers for the user.

Tracker-wide duplicate hunting and cleanup are a separate task.

Then branch off the **up-to-date** default branch **before** committing
anything. Committing on the default branch and branching afterward leaves the
new branch with no commits (push/PR fails with "No commits between"). Compute
the default branch and confirm the switch:

```bash
git fetch origin
default=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
# --no-track is REQUIRED: otherwise upstream becomes origin/$default and a later
# push (e.g. VSCode "Synchronize Changes") would fast-forward your commits onto
# the default branch, bypassing review. With no upstream, a bare `git push`
# fails and VSCode offers "Publish Branch" instead.
git switch --no-track -c kh/fixXYZ "origin/$default"   # or the branch name the user gave
git branch --show-current                                # must print kh/fixXYZ, NOT $default
# Guard: must have NO upstream; if one prints, recreate with --no-track.
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null \
  && echo "ERROR: upstream is set; recreate kh/fixXYZ with --no-track" \
  || echo "ok: no upstream"
```

`kh` = user initials, `XYZ` = issue number. If `git switch -c` fails (e.g. a
name clash), stop and resolve it; never continue on the default branch.
Uncommitted edits from reproducing carry over to the new branch.

### 4a. Fix the bug

- Add the MWE as a regression test. For errors, prefer
  `@test_throws "message users actually see" expr` over (or alongside) the
  exception type.
- Implement the fix. Annotate argument types only as specifically as the
  implementation requires; fail fast on unexpected input.
- Reference the issue in a code comment that states what is true of the code
  now (`# issue #XYZ: ...`; see `code-comments`), never in the commit subject.
- Iterate in the session model step 2 chose; reserve `Pkg.test()` for a final
  full-suite pass.

### 4b. Document the limitation

Edit the README, docstrings, or Documenter `docs/`. Keep any jldoctest or
example runnable.

### Commit (4a, 4b)

- Guard: if `git branch --show-current` shows the default branch, stop and
  create the issue branch (it carries your changes) first. Never `git commit`
  on the default branch.
- Commit locally per the `git-commits` skill. **Do not push** until the user
  has reviewed the change and message.
- Subject ≤ 50 chars (72 max), no issue number. Put `Fixes #XYZ` in the body
  (several: `Fixes #abc; fixes #def`).
- On approval, push the feature branch explicitly: `git push -u origin HEAD`.
  Never push to the default branch. A *Synchronize Changes* prompt in an IDE
  means the upstream is misconfigured; stop and fix it first.

### 4c. Report findings (no change)

Print a concise summary to the user. **Do not post it to GitHub**; the user
handles all communication with the reporter. Cases: reporter-error; already
fixed (include the commit/PR#); cannot replicate (state what you tried and the
Julia channel); still relevant but blocked on an upstream issue.

<!-- Adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
