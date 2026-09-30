---
name: write-methods
description: >-
  Write a methods document for an analysis project — a living account of the whole project or a
  focused explanation of one stage or result. Its main purpose is human-agent alignment:
  reconstruct the chain from data to choices to key results, surface challengeable assumptions,
  and ask the user to confirm the riskiest ones. Renders Markdown to PDF via Pandoc + Typst.
disable-model-invocation: true
---

# Write Methods

You are producing a **methods document** for an analysis project. A methods section in the
classic sense — a paper-ready account of what was done — is a welcome byproduct, but it is not
the goal. The goal is **human-agent alignment**: this document is the verbal counterpart to the
project's figures. Where a figure exposes the *data and results*, this document exposes the
overall shape of an analysis, in a form a busy human can skim and be productively
skeptical about.

The core constraint on a methods documents is that it must remain 
**readable and interpretable** by the human partner. Statements below about data provenence
are strictly secondary, and taken too far have a tendency to create long documents full
of cross references to minor details that may be understandable to an agent but are overwhelming
for a busy human reader.

Topics of interest:

- the mathematical foundation: models, metrics for analysis, and invariants retained and violated
- which analyses were run on which problems/outcomes/types of data
- data provenance — which data actually fed a conclusion. Do *not* go overboard
  on this one. If 80% of your document is on data provenance and burrowing into
  every corner-case, it likely isn't human-readable anymore
- key assumptions and important open questions

## Step 1: Orient — mode and scope

Read the project's own account of what it did, if present: plan or notes files, the
README, `_research/` script headers, and the conversation in this session.

These tell you what the project *claims* it did. Treat them as claims to verify, not as truth
(Step 2 explains why).

Then settle two axes with the user (infer if obvious, ask if not):

- **Mode**:
  - **Focused** — explain one stage or one result ("show me where *this* number came from").
    Cheap, targeted, *ephemeral by default*.
  - **Consolidated** — the whole-project narrative as a *living, durable* `METHODS.md`.
- **Scope**: which stage / result, or the whole project.

If there is no such account, ask the user to point you at the code and the result(s) to
document, then proceed.

A common case: a single session explores **many flavors of the same analysis**, and only one is
worth documenting. Steer this with the invocation itself — e.g. "`/write-methods`, document only
the variant that uses …" — and honor an explicit selection; if which variant matters is unclear,
ask rather than guess. 

State the scope of the document at the beginning.

## Step 2: Delegate the investigation to a subagent where appropriate

The investigation is the expensive part: reading source code, tracing a result back to the data
and parameters that produced it, and checking that against the project's own account. Doing this
in the main session risks filling the context window and degrading your later judgment — including the
quality of the alignment conversation in Step 5. Where this risk seems real, delegate to a subagent.

Practice **targeted skepticism**, not exhaustive audit. Spend the budget only on the
choices that are *load-bearing* for the result(s) in scope — the data subset, the transform and
its parametrization, the ground-truth procedure. Take the project's own notes at face value for
everything else. Verify against the code only where a wrong answer would actually change a conclusion.

Instruct the subagent to read **the code and data as the source of truth**, the plan/Notes as
claims to check against, and to return — for each key result in scope — a brief of this shape:

```markdown
### Key operations
 - **Code locations**: file:line ranges that correspond to models or analyses
 - **Purpose**: what this block exists to do
 - **Operation**: the mathematical equivalent of the same operation (TeX-style math)

### Result: [what it is — a number, a figure, a claim]
- **Origin chain**: data subset used → transform/model → parametrization → output
- **Code locations**: file:line for the load-bearing steps
- **Ground-truth handling**: how ground truth was generated/used, if applicable
- **Verified**: which steps were checked against the code (vs. taken from the plan/Notes)
- **Discrepancies**: where the code disagrees with the plan/Notes, or "none found"
- **Risk flags**: assumptions most likely to be misaligned with user intent;
  results that look "too good" or "too bad" to be true
```

If a value or rationale cannot be recovered from the artifacts, the subagent must report it as a
**gap** — never invent a plausible-sounding parameter or justification. Surfacing the gap is
correct behavior; papering over it defeats the purpose.

## Step 3: Draft the methods document

Write the canonical document as **Pandoc-flavored Markdown** (see Step 4 for why Markdown is the
source format). Structure it around results, not around code organization:

1. **Brief overview** — data, goal, environment, in 2–4 sentences.
2. **Model summary** — exposition of any definitions, models, objective functions, invariants, theorems, etc.
   that form the intellectual core of the project
3. **Analysis methods** — exposition of the key metrics or other measurement operations
   informing the conclusions
4. **Key results** in a logical organization (use block or flat as appropriate for the project),
   together with their origin chain. Prefer to embed figures and tables rather than make
   references to artifacts.
5. **Assumptions to check** — list of the load-bearing choices, each phrased as
   a challengeable statement the user can accept or reject:
   - "Region X of the image was treated as the feature of interest."
   - "The model was parametrized as A rather than B."
   - "Ground truth was assumed to be generated by process P."
6. **Gaps** — important limitations that might circumscribe some of the conclusions.

Write equations as TeX-style math (`$…$`, `$$…$$`): Pandoc converts it to Typst math, Word
equations, and MathJax. Use
American spellings. Use standard terminology and avoid agent-invented jargon.

If the document is a living document, give some consideration to the risk of
loss:
- material that you can establish to be invalid should be retired without comment
- material that is orthogonal to your state of knowledge should be retained,
  taken at face value, and woven in with other edits to give a coherent, readable
  narrative
- previous sections that appear detached from the central narrative, but can be
  neither verified nor invalidated, may need to be retained in a "Legacy"
  section, marked as historical materials (preferably with a date estimate) and
  what investigation would be required to promote or retire the material. 

## Step 4: Render to a rich format

The canonical artifact is Markdown; rich formats are **render targets** produced by
**Pandoc**. Markdown is reviewable as-is in any editor or on GitHub.

1. **Always** write the Markdown first; it is the commit-worthy object.
2. Default: **PDF via Typst** (both `pandoc` and `typst` are installed on this machine):

   ```sh
   pandoc methods.md -o methods.typ --standalone
   typst compile methods.typ methods.pdf
   ```

   Keep the `.typ` file only if the user wants to edit or lift it into a Typst manuscript.
   Pandoc can also do both steps: `pandoc methods.md -o methods.pdf --pdf-engine=typst`.
3. Alternatives on request: **`.docx`** (`pandoc methods.md -o methods.docx`; math becomes
   native Word equations) or **self-contained HTML** (`pandoc methods.md -s --embed-resources
   --mathjax -o methods.html`). In Claude Code the HTML can be published as a private Artifact
   for viewing.
4. If a renderer is missing, stop at Markdown and **say so explicitly** with a one-line install
   hint, rather than presenting the Markdown as the finished artifact.

For figures, prefer **PNG** (safe across Typst, Word, and HTML). Figures should usually exist
already; if they are missing or look stale, ask whether to re-render them.

If the project already uses **Quarto**, you may render through it instead (it supports Typst
output). Do not introduce Quarto as a new dependency.

## Step 5: Active confirmation checkpoint

The point of all of this is alignment, so do not write-and-leave. Close by
giving the user the opportunity to ask for upgrades. Surface any issues
that you think merit particular attention from the user.

This step should be done only after the document has been successfully rendered in human-readable format.

## Step 6: Persist or discard

- **Consolidated mode**: write/update `METHODS.md` in the project root (or a `docs/` location the
  user specifies), with the reconciliation from Step 3. This is a durable, living document.
- **Focused mode**: write to a temporary file (e.g. `/tmp/methods-<stage>.md`, or the system temp
  directory) and tell the user the path, noting they can copy it somewhere permanent if they
  decide to keep it. Do not clutter the project with one-off methods notes by default.

## Important notes

- **Source of truth is the code, not the project's self-description.** The plan and Notes are
  claims to verify. Re-narrating a possibly-wrong self-account defeats the purpose.
- **Never fabricate.** A recovered gap reported honestly is worth more than a fluent invention.
- Do **not** modify analysis code or rerun the pipeline here — this skill documents and verifies;
  it does not implement. If it uncovers a bug or misalignment, report it to the user.

<!-- Adapted from Tim Holy, timholy/claude_config (MIT); see dot-agents/THIRD_PARTY_LICENSES.md -->
