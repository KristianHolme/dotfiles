---
name: code-comments
description: >-
  Standard for code comments, docstrings, and commit messages: state what the
  code is now, not its history or the plan it came from. Use whenever writing or
  editing comments, docstrings, or commit messages, and especially right after
  working from a plan, review, or debugging session.
---

# Code comments

A comment explains the code that is there *now*: an invariant it must maintain,
a non-obvious reason it has to be this way, a constraint a future editor would
otherwise break. Write every comment so it still reads correctly to someone who
has only the repository in front of them — no plan, no chat log, no memory of
how the code came to be. If a sentence only makes sense to someone who watched
the code being written, it does not belong in the source.

State what *is* true, not what *was* true or *why you happened to write it
today*:

- ✗ `# CHUNK-3: reuse the sparse format chosen earlier so alignment stays fast`
- ✓ `# Sparse storage: nearly all off-diagonal weights are zero.`

- ✗ `# Formerly a dense loop; switched to this for speed`
- ✓ usually *no comment* — the code stands on its own. Add one only if a future
  editor would otherwise reintroduce the slow form, and then state *why the fast
  form is required*, not what it replaced.

- ✗ `# as planned in the design doc, normalize before the fit`
- ✓ `# Normalize first: the solver assumes unit-scaled columns.`

Corollaries:

- **Never reference a planning artifact, chunk ID, session note, or "as
  planned".** A planning document is fair to cite only when it is a durable,
  committed file *in the repository itself*. A GitHub issue/PR number is fine as
  a terse pointer (`# see #123`) when the issue records context the code cannot
  — but it never substitutes for stating what the code does.
- **History lives in the commit log, not the source.** "Previously…",
  "Formerly…", "Regression:…", "this used to…" — drop them. The rare exception
  is when the history is the *only* thing that stops a future editor from
  re-making a mistake; then write the constraint as a present-tense fact ("must
  stay ≥ ε — zero triggers a singular solve"), not as a story about the past.
- **Intent and invariants, not motivation or biography.** No "motivating
  example", no roadmap, no "for now".
- **Match the surrounding code** in density, detail, and abstraction level.
  Sparse code gets sparse comments.
- **Write for a human**, not for an agent and not for yourself mid-task.

The same principle governs commit messages and docstrings: describe the change
and the invariant it establishes for a reader who has only the repository.

This applies with special force right after you have worked from a plan. The
plan, the session handoff, and the accumulated working-knowledge you just read
are scaffolding for *you*. The code, its comments, and the commit message must
read as if that scaffolding never existed.

For wording (jargon, intensifiers, em-dash chains), see the Wording section of
[agent-communication](../agent-communication/SKILL.md). To clean up existing prose
in bulk, the user can run `plain-prose`.

<!-- Adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
