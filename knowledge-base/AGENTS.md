# AGENTS.md - Knowledge Base

This folder contains a personal knowledge management system based on Andrej Karpathy's LLM Knowledge Base workflow.

## Structure

```
~/Knowledge/
├── inbox/     # Drop new items here (PDFs, articles, notes)
├── raw/       # Agent moves organized items here from inbox
└── wiki/      # Compiled knowledge (always links to raw/, never copies)
```

## Workflow

1. **User** drops new items in `inbox/`
2. **Agent** processes inbox → moves to `raw/` (organized naming) + creates wiki note with link
3. **Wiki** notes always contain `raw: "[[../../raw/path/to/file]]"` links

## Key Rule

**Never duplicate content in wiki.** Always link to raw/ materials.

Example wiki note frontmatter:
```yaml
---
title: Paper Title
date: 2024-01-15
raw: "[[../../raw/papers/author-2024-title.pdf]]"
---
```

## Tools Available

- **QMD** (`qmd search`) - Fast full-text search
- **ripgrep** (`rg`) - Fallback text search
- **pdftotext** - Extract PDF text
- File operations (cat, mv, ls) - Move items, create notes

## When User Asks

- "What's in my inbox?" → `ls ~/Knowledge/inbox/*/` or `find ~/Knowledge/inbox -type f`
- "Process my inbox" → Move items to raw/, create wiki notes with links
- "Search for..." → `qmd search "query"`
- "Create note for..." → Create in wiki/ with proper links to raw/

## File Naming in raw/

Use descriptive names when moving from inbox to raw:
- Papers: `author-year-title-keywords.pdf`
- Web: `site-date-title.md`
- Code: `date-project-name/`

## Syncthing

The entire ~/Knowledge folder is synced across devices via Syncthing.
Web UI: http://localhost:8384
