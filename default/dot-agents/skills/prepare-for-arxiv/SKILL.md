---
name: prepare-for-arxiv
description: Use when arXiv LaTeX submission prep is needed—only in a `tmp/` copy, flattening subdirectories and paths, pruning cruft and build artifacts, `.bbl` vs `.bib` cleanup, tarball packaging, a human PDF-review gate before upload, or interactive confirmation before deletes, comment stripping, and path rewrites; or when the user cites Trevor Campbell’s arXiv checklist.
---

# Prepare for arXiv (LaTeX source)

## Reference

Primary checklist and rationale: [Uploading a paper to arXiv.org](https://trevorcampbell.me/html/arxiv.html) (Trevor Campbell). Follow that page for full context; this skill maps **who does what** and enforces **work only under `tmp/`**.

## Principles

- **Never modify the original project tree.** All destructive steps use a deep copy (Campbell step 1).
- **Step numbers below match the numbered list on the reference page** so the user can cross-check.
- After **step 8**, stop for human approval. Do not run steps 9–11 until the user explicitly signals to continue (e.g. “looks good, continue”, “proceed with bbl and tarball”).

## Collaboration (required)

**Default posture:** co-pilot with the user, not autonomous cleanup. At **each** Campbell phase the agent touches (1, 4–7, 8–11), use a short **assess → propose → confirm → act** loop.

1. **Assess** — Inspect `tmp/` (or the paths the user gave). State what the guide expects at this step and what you found (e.g. subdirs, obvious build junk, `.bib` files).
2. **Propose** — List **concrete** next actions: files/dirs to move or delete, path edits, comment policy, exact snippet to append, compile command, tarball contents. Use checklists or tables when there are many paths.
3. **Confirm** — **Do not delete, move, rewrite, or run destructive shell** until the user agrees. Ask clear questions (“Delete the4 paths below?”, “Strip comments only in `main.tex` or all `.tex`?”). Use the host’s question, plan, or confirmation UI **when available**; otherwise ask in the message and wait for an explicit reply.
4. **Act** — Only perform what was approved. If something new appears mid-step (e.g. an unexpected `\input`), stop and re-confirm.

**Never batch-skip confirmation** by assuming “obvious” junk is safe. Hidden dirs, “unused” `.tex`, and comments are especially user-specific.

## Agent scope vs user scope

| Steps | Who |
|-------|-----|
| **1** | Agent may run the deep copy when the user supplies the source directory and confirms the `tmp` path (e.g. `cp -r your_paper_dir tmp`). Warn if `tmp` already exists. |
| **2–3** | **User** (structure, appendix merge, journal/published wording). Do not merge appendices or edit journal branding unless the user explicitly asks. |
| **4–7** | **Agent** (technical, inside `tmp/` only): flatten dirs, fix paths, prune cruft, comments—**only after user confirms each proposal**; see **Collaboration** and step sections below. |
| **8** | **User** compiles in `tmp/` and inspects the PDF. Agent may run `pdflatex`/`latexmk` if the user wants, but **must pause for user inspection and explicit go-ahead** before step 9. |
| **9–11** | **Agent** after go-ahead: list generated files to remove vs keep, list `.bib` to delete, show `tar` plan—**confirm** then retain `.bbl`, delete the rest, build `ax.tar`. |
| **12+** | **User** (arXiv web UI, metadata, final log/PDF checks, advisor-facing choices). After step 11, give the handoff message in **Handoff after `ax.tar`**. |

## Technical workflow (agent)

Each subsection follows **Collaboration**: assess → propose → **user confirms** → act.

### Step 1 — Deep copy

- **Assess:** Does `tmp` (or the chosen copy name) already exist? How large is the tree?
- **Propose:** Exact command (e.g. `cp -r …`) and destination; note overwrite risk.
- **Confirm:** Ask whether to proceed, use a different `tmp` name, or remove/backup an existing `tmp`.
- **Act:** Run copy only after explicit approval.

### Before step 4 — Project shape

- **Ask** (if not already known): entry `.tex` name, bibliography workflow (BibTeX vs biblatex), whether Campbell steps **2–3** are done or deliberately skipped, any nonstandard build steps.
- **Do not** start flattening until the user answers or defers those items clearly.

### Step 4 — Flatten

- **Assess:** Map subdirectories and assets (`figures/`, `sections/`, etc.) vs what the main file pulls in.
- **Propose:** A table or list: each **move/rename** (old path → new basename), then which `.tex` lines will change (`\includegraphics`, `\input`, etc.). Flag basename collisions.
- **Confirm:** Ask whether to proceed with **this exact** flattening plan (or adjust).
- **Act:** Move/rename and edit only after approval. If you discover a new dependency, pause and re-confirm.

### Step 5 — Delete unneeded material

Work in **categories**; get **confirmation per category** (or one consolidated list the user approves in full).

- **Hidden / VCS / editor:** e.g. `.git`, `.github`, `.cursor`, swap files — list paths, ask to delete.
- **Build artifacts:** `.pdf`, `.aux`, `.log`, `.out`, `.blg`, `.toc`, `.synctex.gz`, etc. — list what you found; ask to delete (usually yes, but user may want to keep a reference PDF until step 8).
- **Unused sources:** `.tex`, `.sty`, `.cls` that appear unused — list **candidates with rationale** (“not `\input` from main”, “duplicate draft”). **Never delete** these without explicit per-file or batch approval.

Remind: everything in the upload tarball becomes public.

### Step 6 — Comments

- **Assess:** Scope of `%` comments (draft notes, TODOs, `%` inside tricky environments).
- **Propose:** Choose one: **skip**; **manual files only** (user names them); **all `.tex`** with a stated strategy (e.g. skip `verbatim` blocks); or **show 2–3 sample removals** first.
- **Confirm:** User picks scope and strategy. If they are unsure, recommend skipping or minimal samples.
- **Act:** Apply only the agreed scope. Verbatim-like environments remain high-risk—prefer leaving those to the user.

### Step 7 — Multi-pass hint

- **Propose:** Show the **exact** file, insertion point (after `\end{document}`), and one-line snippet:

```latex
\typeout{get arXiv to do 4 passes: Label(s) may have changed. Rerun}
```

- **Confirm:** User approves the edit (correct entry file if not `main.tex`).
- **Act:** Apply the line only after approval.

### Step 8 — Compile and checkpoint

- **Propose:** Exact compile command(s) or `latexmk` invocation you intend to run in `tmp/`.
- **Confirm:** User approves running compile, or prefers to compile locally themselves.
- **Act:** Run if approved; collect log warnings/errors.
- **Stop:** Ask the user to inspect the PDF. **No step 9** until they explicitly continue (PDF OK, proceed to `.bbl`/tarball).

### Steps 9–11 — After user go-ahead

1. **Assess:** List every file created by the last compile.
2. **Propose:** “**Keep:** `…/foo.bbl`” and “**Delete:** …” for `.aux`, `.log`, `.pdf`, etc. Ask if any generated file must be kept.
3. **Confirm:** User approves the delete list.
4. **Act:** Delete only as approved; **preserve** the agreed `.bbl`.
5. **Propose:** List all `.bib` paths to remove; remind that arXiv will use `.bbl` only.
6. **Confirm:** User approves deleting those `.bib` files.
7. **Act:** Delete `.bib` as approved.
8. **Propose:** `tar` command (`tar -cvvf ax.tar *` from `tmp/`) and warn that `*` omits dotfiles—ask if any dotfile must be included.
9. **Confirm:** User approves creating `ax.tar`.
10. **Act:** Create the tarball.

## Handoff after `ax.tar`

Tell the user:

- Agent work for the Campbell checklist **stops** after step 11.
- **Steps 12 onward** (upload UI, prune “unnecessary” extracted files per arXiv, inspect server `pdflatex` log and generated PDF, plain-text abstract/title/authors, subject area, coauthor passwords) are **manual** and should be done by them with advisor/input as the page describes.
- Re-link the full guide: https://trevorcampbell.me/html/arxiv.html

## Common mistakes

- Editing the original repo instead of `tmp/`.
- Flattening without fixing every path (figures, inputs, `.bbl` location).
- Deleting, moving, or bulk-editing without a **prior** user-approved list.
- Proceeding past compile inspection without explicit user approval.
- Removing `.tex` files that are actually `\input` from the main document.
- Comment stripping inside verbatim-like environments.
- Assuming “standard” cleanup (e.g. always delete PDF before step 8) without asking.
