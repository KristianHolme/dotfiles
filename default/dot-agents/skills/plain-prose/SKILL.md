---
name: plain-prose
description: Rewrite a package's prose (docstrings, comments, docs pages, README) so it states what the code is and does now, in plain language, at the length the reader needs. Use when the user asks to clean up, simplify, or de-jargon comments or docs, or to strip history and planning narrative from them; not for writing new documentation.
disable-model-invocation: true
---

Rewrite the prose in a package as if written by someone with only the
repository in front of them. `$ARGUMENTS` may be a file, directory, or list of
paths; if omitted, cover the whole package: `src/`, `ext/`, `test/`,
`docs/src/`, `README.md`, and sibling subdir packages in a monorepo. Skip
generated files, golden/expected fixtures, and `assets/` except where step 3
proposes removing one.

Prose only. Do not change code, identifiers, signatures, behavior, or test
assertions. The only other edits allowed keep a docs build working after a
page or asset removal approved in step 3.

First read [code-comments](../code-comments/SKILL.md) and the Wording section
of [agent-communication](../agent-communication/SKILL.md); they define the
standard, this skill is the procedure. Prose written during a plan, review, or
debugging session carries that context (argues for decisions, addresses a
reviewer, records old behavior, describes other call sites); this pass strips
it in one sweep per file.

## 1. Scope and baseline

List the files in scope. If `docs/make.jl` exists, note its page list and asset
references for step 4. Require a clean working tree so the diff holds only
this pass.

## 2. Rewrite

Per file, for each docstring, comment block, or Markdown section: decide what
it should cover (2b), then write it plainly (2a).

### 2a. Wording

Apply every rule in the Wording section of agent-communication. Also replace:

- **Intensifiers and reassurance**: "small", "clear", "actionable", "on
  purpose", "correctly so", "not a gap".
- **History and planning language**: "today's semantics, unchanged",
  "historical", "pre-flag", "existing", "for the record", "rejected
  alternative", "the round-2 report", "the sweep", "an upstream fix is in
  progress". A rejected design becomes "X is not supported" plus a one-sentence
  reason if it stops a future editor from re-adding it.
- **Reviewer-addressed commentary** ("The real test:", "verified by probe, not
  assumed", "pinned rather than silently assumed safe", "this whole function is
  a workaround for …") with nothing.
- **Process-named section titles** ("Where they sit in the layer plan") with
  content-named ones ("Architecture").

Use American spelling.

### 2b. Length

Target: what a competent reader needs to use the code correctly.

**Docstrings.** Keep the signature line, what it returns, what it requires of
inputs, what it rejects or throws, and caller contracts (ownership, who frees,
column-major layout, thread-safety). An internal helper is usually one to
three sentences. Remove:

- descriptions of other functions or call sites ("the two places that rely on
  this");
- field-by-field restatement of a struct defined in the same file;
- why a parameter is passed in rather than hard-coded, or why recognition is by
  shape rather than package;
- enumerations of cases that do not occur;
- boilerplate repeated across siblings ("Target-independent: operates on
  `ABIInfo` only"); if it matters, say it once in a file-header comment;
- `(see X for the rationale)` chains to a removed rationale.

**Comments.** One line stating the invariant or non-obvious reason. A comment
paraphrasing the next line goes. A multi-paragraph comment on why a branch
exists becomes one sentence naming the condition it handles.

**Test comments.** One line naming what the testset verifies; no fixture
origin story.

**Docs pages.** Propose, do not perform without approval: merging a page that
re-explains types documented elsewhere; removing a diagram that restates a
struct layout shown in code; deleting subsections that only justify a design.
Format: "page/asset → what would absorb it → what is lost."

**Preserve, condensing wording but not content:**

- invariants a future editor would break ("`dims` precedes `data`; the C
  emitter depends on this order");
- issue/PR references recording context the code cannot (`# see #123`),
  including upstream issues marking a workaround removable; keep them terse;
- hazards: a view that must not outlive its buffer, a function not to call
  twice, a size limit that throws;
- `@ref` targets, doctests, and cross-references the docs build needs;
- user-facing warnings about behavior differing from assumption (e.g. a numpy
  array must be Fortran-contiguous).

## 3. Review with the user

Present: `git diff --stat`; the docs-page/asset proposals awaiting a decision;
and a **judgment-call list** of removed passages that held information (not
just wording), one line each. Deleted issue/PR references and hazard warnings
go first. **[pause for approval]** Then apply approved page/asset changes
(updating `docs/make.jl`) and restore anything the user asks for.

## 4. Verify

- `git diff` touches only comment lines, docstring bodies, Markdown, and (if
  approved) `docs/make.jl` and assets. Spot-check any non-obvious hunk.
- For a fully removed docstring, ensure no `@ref` links to it and no `@docs`
  block lists the symbol.
- If `docs/make.jl` exists, build (`juliaclient --project=docs docs/make.jl`)
  and confirm no new missing-docs or cross-reference warnings. If doctests
  live in the test suite, run them.

## 5. Commit and report

Commit once, subject like "Simplify and condense prose". Report lines removed
vs added; docs proposals and outcomes; the judgment-call list with decisions;
and any passage left alone because history vs live constraint was unclear.

<!-- Adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
