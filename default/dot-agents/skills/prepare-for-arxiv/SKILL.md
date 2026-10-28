---
name: prepare-for-arxiv
description: Use when arXiv LaTeX submission prep is needed—only in a `tmp/` copy, flattening subdirectories and paths, pruning cruft and build artifacts, `.bbl` vs `.bib` cleanup, tarball packaging, a human PDF-review gate before upload, or interactive confirmation before deletes, comment stripping, and path rewrites; or when the user cites Trevor Campbell’s arXiv checklist.
---

# Prepare for arXiv (LaTeX source)

Checklist and rationale: [Uploading a paper to arXiv.org](https://trevorcampbell.me/html/arxiv.html) (Trevor Campbell). Step numbers below match its numbered list. This skill sets who does what and confines work to `tmp/`.

## Rules

- **Never modify the original project tree.** All destructive steps run on a deep copy in `tmp/`.
- After **step 8**, stop for human approval. Do not run steps 9–11 until the user explicitly continues (e.g. "looks good, proceed with bbl and tarball").
- Everything in the upload tarball becomes public.

## Collaboration loop

Co-pilot, not autonomous cleanup. At each step the agent touches (1, 4–11), run **assess → propose → confirm → act**:

1. **Assess**: inspect `tmp/` and state what the guide expects and what you found.
2. **Propose**: concrete actions (files to move/delete, path edits, exact commands, snippets). Use lists or tables for many paths.
3. **Confirm**: do not delete, move, rewrite, or run destructive shell until the user agrees. Use the host's question UI if available; otherwise ask and wait for an explicit reply.
4. **Act**: do only what was approved. If something new appears (e.g. an unexpected `\input`), stop and re-confirm.

Never skip confirmation because junk looks obvious. Hidden dirs, "unused" `.tex`, and comments are user-specific.

## Who does what

| Steps | Who |
|-------|-----|
| **1** | Agent, when the user gives the source dir and confirms the `tmp` path (e.g. `cp -r your_paper_dir tmp`). Warn if `tmp` exists. |
| **2–3** | **User** (structure, appendix merge, journal wording). Do not merge appendices or edit journal branding unless asked. |
| **4–7** | Agent, inside `tmp/` only, each proposal user-confirmed. |
| **8** | User compiles and inspects the PDF. Agent may run `pdflatex`/`latexmk` if asked, then must pause for explicit go-ahead. |
| **9–11** | Agent after go-ahead. |
| **12+** | **User** (arXiv web UI, metadata, log/PDF checks). |

## Steps

### Before step 4

Ask (if unknown): entry `.tex` name, bibliography workflow (BibTeX vs biblatex), whether steps 2–3 are done or skipped, nonstandard build steps. Do not flatten until answered or clearly deferred.

### Step 1: deep copy

Propose the exact command and destination; note overwrite risk if `tmp` exists and offer another name or backup.

### Step 4: flatten

Map subdirectories and assets against what the main file pulls in. Propose each move/rename (old path → new basename) and which `.tex` lines change (`\includegraphics`, `\input`, ...). Flag basename collisions.

### Step 5: delete unneeded material

Get confirmation per category, or one consolidated approved list.

- **Hidden / VCS / editor:** `.git`, `.github`, `.cursor`, swap files.
- **Build artifacts:** `.pdf`, `.aux`, `.log`, `.out`, `.blg`, `.toc`, `.synctex.gz`. Usually delete, but the user may want a reference PDF until step 8.
- **Unused sources:** `.tex`, `.sty`, `.cls` that look unused. List candidates with rationale ("not `\input` from main", "duplicate draft"). Never delete without explicit per-file or batch approval.

### Step 6: comments

Propose one: skip; manual files only (user names them); all `.tex` with a stated strategy (e.g. skip `verbatim`); or show 2–3 sample removals first. If the user is unsure, recommend skipping or samples. Verbatim-like environments are high-risk; leave them to the user.

### Step 7: multi-pass hint

Propose the entry file and insertion point (after `\end{document}`):

```latex
\typeout{get arXiv to do 4 passes: Label(s) may have changed. Rerun}
```

### Step 8: compile and checkpoint

Propose the exact compile command (or let the user compile). Run if approved and collect log warnings/errors. Then ask the user to inspect the PDF; **no step 9** until they continue.

### Steps 9–11

1. List every file the compile created; propose Keep (`…/foo.bbl`) and Delete (`.aux`, `.log`, `.pdf`, ...). After approval, delete and preserve the `.bbl`.
2. List all `.bib` paths to remove (arXiv uses `.bbl` only); delete after approval.
3. Propose `tar -cvvf ax.tar *` from `tmp/`; warn that `*` omits dotfiles and ask if any must be included. Create after approval.

## Handoff after `ax.tar`

Tell the user: agent work stops after step 11. Steps 12+ (upload UI, pruning extracted files per arXiv, the server `pdflatex` log and PDF, plain-text abstract/title/authors, subject area, coauthor passwords) are manual, per https://trevorcampbell.me/html/arxiv.html.

## Common mistakes

- Flattening without fixing every path (figures, inputs, `.bbl` location).
- Removing `.tex` files that are `\input` from the main document.
- Assuming "standard" cleanup (e.g. always delete the PDF before step 8) without asking.
