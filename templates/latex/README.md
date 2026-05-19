# LaTeX Templates for omarchy-tweaks

This directory contains LaTeX project templates for use with the `dotfiles-latex-init.sh` script.

Each template lives in its own folder under `templates/latex/<name>_template/`.

## Available Templates

### `default_template/`
Plain LaTeX article with a minimal preamble.

- `main.tex` — document entry point
- `preamble.tex` — shared packages and layout

```bash
./dotfiles-latex-init.sh -t default my-doc
```

### `uio_presentation_template/`
University of Oslo official beamer presentation.

- `main.tex` — minimal starter presentation
- `preamble.tex` — comprehensive UiO beamer options and configuration
- `example.tex` — fuller example deck with section structure

```bash
./dotfiles-latex-init.sh -t uio-presentation my-uio-talk
```

#### Features
- Official University of Oslo branding and colors
- Professional presentation layout following UiO guidelines
- Support for section headers, TOC, summary slides
- Multiple font options (Arial, Noto, Arev)
- Official UiO color palette

#### Theme Options Available
- `sectionheaders` — show section/subsection names in header
- `summary` — add summary page at end
- `toc` — automatically insert table of contents
- `uiostandard` — follow UiO standard strictly (square bullets, etc.)
- `sectionsep=color` — add colored section separator frames
- `font=arial|noto|arev|none` — font selection

#### UiO Colors
- Blues: `uioblue1`, `uioblue2`, `uioblue3`
- Greens: `uiogreen1`, `uiogreen2`, `uiogreen3`
- Oranges: `uioorange1`, `uioorange2`, `uioorange3`
- Pinks: `uiopink1`, `uiopink2`, `uiopink3`
- Others: `uioyellow`, `uiogrey`

#### Special Commands
- `\uiofrontpage[options]` — create official UiO front page
- `\uioemail{email}` — set email address
- `\uiobigimage{title}{file}{copyright}` — full-page image with frame
- `\uiofullpageimage{file}` — completely full-page image
- `uioimageframe` environment — half text, half image slides

### `arxiv_preprint_template/`
arXiv preprint layout with versioned sources and a latexdiff helper.

- `v0/main.tex` — versioned manuscript source
- `v0/arxiv.sty` — arXiv-style layout
- `diff.tex` — generate a latexdiff between `v0/` and `v1/`

```bash
./dotfiles-latex-init.sh -t arxiv-preprint my-paper
```

This creates:
- `src/main.tex` — active manuscript (copied from `v0/main.tex`)
- `src/v0/` — baseline version directory
- `diff.tex` — project-level latexdiff driver

Create `src/v1/` when you want to track a revised version and run `latexmk diff.tex`.

## Dependencies

The UiO beamer theme requires the UiO beamer package. At UiO, this is typically available in:
- `/home/kristian/texmf/tex/latex/beamer/uiobeamer/`

For personal computers, download from:
- https://www.mn.uio.no/ifi/tjenester/it/hjelp/latex/uiobeamer.zip

The package setup script installs this automatically via `dotfiles-setup-packages.sh`.

## Notes

- UiO presentations should use 16:9 aspect ratio (default in template)
- Front page images should ideally be 8:9 aspect ratio
- Full-page images should be 16:9 aspect ratio
- Templates are integrated with VimTeX for easy compilation
