---
name: freshen-docstrings
description: Audit and improve a Julia package's docstrings — missing docs on exported/public symbols, outdated signatures, missing return descriptions, style, clarity, and examples. Uses a deterministic Julia harvest plus a cheap reviewing subagent to keep the main context small. Use when the user asks to audit, check, or improve docstrings or documentation coverage of a Julia package.
disable-model-invocation: true
---

# Freshen docstrings

The harvest is deterministic Julia code; only its text output is judged by a model.
That keeps the cost low: the main session never reads the full source.

## 1. Harvest

Needs Julia ≥ 1.11 (`Base.Docs._doc`). Run from the package root, with `<skill-dir>`
the directory of this SKILL.md, and write the output to a file:

```sh
juliaclient --project --revise=yes -e 'include("<skill-dir>/scripts/audit_docstrings.jl"); using MyPackage; audit_docstrings(MyPackage)' > /tmp/docaudit-MyPackage.txt
```

If the default Julia channel is older than 1.11, use `julia +release --project -e ...`
instead. If the call errors, report the error and stop. Do not fall back to reading
source files.

## 2. Judge

Delegate to a subagent with [references/docstring-auditor.md](references/docstring-auditor.md)
as its prompt and the output file path. A fast, cheap model is enough. If no
subagent is available, apply the same prompt inline. The subagent returns a
per-symbol issue list (`missing_docstring`, `outdated_signature`, `missing_return`,
`style`, `clarity`, `missing_example`, `oversplit`, `underdifferentiated`) with
`file:line`, plus a summary.

Optional cross-check when the package has a Documenter build: `checkdocs = :exports`
in `docs/make.jl` reports exported symbols missing from the manual.

## 3. Summarize

Report to the user:

- symbols missing docstrings, split into exported vs. public-but-not-exported;
- existing docstrings with issues;
- recommendations limited to changes that help users of the package.

**[pause for approval]** Wait for the user to choose which issues to fix.

## 4. Implement

- Write new docstrings and fix approved issues. A docstring states what the symbol does
  and the contract it holds, not its history (see `code-comments`). Julia style: 4-space
  indented signature, backticks, blank line after the signature block, imperative first
  sentence.
- Use targeted reads and edits at the `file:line` from the audit, not full-file reads.
  Edit from the end of each file towards the start so the remaining line numbers stay valid.
- Test every example with `juliaclient --project --revise=yes`. Assume `using MyPackage`
  was run; spell out any other setup.
- Doctest coverage: if `docs/` has a Documenter build, doctests run there. If not, and
  `test/runtests.jl` has no doctests, propose (with user approval, since it changes
  `Project.toml`) adding `Documenter` as a test dependency and:

  ```julia
  using Documenter
  DocMeta.setdocmeta!(MyPackage, :DocTestSetup, :(using MyPackage); recursive = true)
  @testset "Doctests" begin
      doctest(MyPackage)
  end
  ```

<!-- Adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
