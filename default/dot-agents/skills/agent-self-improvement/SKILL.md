---
name: agent-self-improvement
description: >-
  Capture corrections and wrong assumptions into durable agent guidance. Always
  apply in coding sessions: when the user corrects a mistake, a false assumption,
  a missing convention, or a surprising tool/API behavior, propose a short
  addition to the relevant skill, AGENTS.md, or other appropriate doc — do not
  silently forget it.
---

# Agent self-improvement

When something goes wrong in a way that future agents would repeat, treat it as a **durable knowledge gap**, not only a one-off fix.

## When this applies

Trigger after any of:

- User corrects a factual or API mistake
- A wrong assumption is exposed (defaults, merge order, precedence, “like X in Julia/Python”)
- A project- or stack-specific convention is stated that was not in skills/`AGENTS.md`
- You discover surprising behavior the hard way and the user confirms it

Skip trivial typos, one-off preferences, or secrets.

## What to do

1. **Acknowledge** the correction briefly (fix the code/docs as needed).
2. **Propose capture** in the same turn (or immediately after the fix): one short line (or two) of guidance, and **where** it should live.
3. **Ask before writing** — do not edit skills/`AGENTS.md` unless the user agrees (or they already asked you to add it).

### Where to put it

| Kind of knowledge | Prefer |
|-------------------|--------|
| Stack/workflow reused across repos (Makie, Julia style, git, …) | Matching skill under `~/.agents/skills/` (dotfiles: `default/dot-agents/skills/`) |
| Repo-specific convention | Project `AGENTS.md` (or existing project agent doc) |
| Unclear / one-off | Ask the user which of the above |

Keep additions **short** — one sharp rule beats a paragraph. Link out only if needed.

### Example proposal shape

> Worth capturing so this does not recur — add to `makie-core` Themes:
> `Theme` merge priority is the **opposite** of `merge` on Julia `Dict`s (later themes do not override the same way dict values do). OK to add?

## Anti-patterns

- Do not dump long postmortems into skills
- Do not create a new skill for a single line — extend an existing one when possible
- Do not auto-commit skill changes unless asked
