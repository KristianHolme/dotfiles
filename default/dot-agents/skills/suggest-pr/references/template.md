# No-template shape and summary definitions

Read when the repo has no PR template, or when you must classify "who can hit it".

## Default shape

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

## Who can hit it

Pick one.

- **Low-level internal.** Only code inside the package hits it (for Julia: an unexported helper only the package calls).
- **Mid-level internal.** A user hits it only by calling an internal name outside the public API (an unexported name reached via `Module.name`).
- **User-facing.** A user of the public API can hit it. For Julia, the public API is the exported and documented interface.

Write plain sentences: "This change is not breaking." "Only low-level internals change. A public caller does not hit this."

**Breaking:** a caller that works today must change, or a public result changes. Existing callers keeping the same result is not breaking.
