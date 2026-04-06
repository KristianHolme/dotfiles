# AGENTS.md - Knowledge Base

This folder contains a personal knowledge management system based on Andrej Karpathy's LLM Knowledge Base workflow.

## Structure

```
~/Knowledge/
├── inbox/     # Drop new items here (PDFs, articles, notes)
├── raw/       # Agent moves organized items here from inbox
├── code/      # Julia projects for data analysis and plotting
└── wiki/      # Compiled knowledge (links to raw/ and code/)
```

## Workflow

### Document Ingest
1. **User** drops new items in `inbox/`
2. **Agent** processes inbox → moves to `raw/` (organized naming) + creates wiki note with link
3. **Wiki** notes always contain `raw: "[[../../raw/path/to/file]]"` links

### Data Analysis
1. **User** asks for data analysis/plots
2. **Agent** creates Julia project in `code/project-name/`
3. **Script** generates plots to `raw/plots/` and processed data to `raw/data/`
4. **Agent** creates wiki note linking to:
   - Plot: `![Results](../../raw/plots/figure.png)`
   - Script: `[[../../code/project-name/scripts/plot.jl]]`
   - Raw data: `[[../../raw/data/source.csv]]`

## Key Rules

**1. Never duplicate content in wiki.** Always link to raw/ and code/ materials.

**2. Prefer Julia for data analysis.** Use julia-mcp MCP server for persistent sessions to avoid TTFX issues.

**3. Plots go to raw/plots/, scripts stay in code/.** Wiki documents both.

Example wiki note frontmatter:
```yaml
---
title: Analysis Results
date: 2024-01-15
---

## Plots
![Results](../../raw/plots/experiment.png)

## Script
[[../../code/experiment-analysis/scripts/plot.jl|Source code]]

## Data
[[../../raw/data/experiment.csv|Raw data]]
```

## Tools Available

- **QMD** (`qmd search`) - Fast full-text search
- **ripgrep** (`rg`) - Fallback text search
- **pdftotext** - Extract PDF text
- **Julia** - Data analysis and plotting (prefer over Python/R)
- File operations (cat, mv, ls) - Move items, create notes

## Julia MCP Server

When doing data analysis:
1. Use `julia-mcp` MCP server for persistent Julia sessions
2. This avoids TTFX (time to first execution) issues
3. Iterate quickly without recompiling

## When User Asks

- "What's in my inbox?" → `ls ~/Knowledge/inbox/*/` or `find ~/Knowledge/inbox -type f`
- "Process my inbox" → Move items to raw/, create wiki notes with links
- "Search for..." → `qmd search "query"`
- "Create note for..." → Create in wiki/ with proper links to raw/
- **"Analyze this data..."** → Create Julia project in code/, generate plots to raw/plots/, create wiki note linking both
- **"Plot these results..."** → Use Julia (Makie/Plots.jl), save to raw/plots/, link from wiki/

## File Naming

### In raw/
- Papers: `author-year-title-keywords.pdf`
- Web: `site-date-title.md`
- Plots: `analysis-name-description.png`
- Data: `experiment-name.csv`

### In code/
- Project folders: `analysis-name/`, `experiment-name/`
- Each project has `Project.toml`, `src/`, `scripts/`

## Syncthing

The entire ~/Knowledge folder is synced across devices via Syncthing.
Web UI: http://localhost:8384
