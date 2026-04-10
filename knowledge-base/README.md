# Knowledge Base System

Personal knowledge management system based on Andrej Karpathy's [LLM Knowledge Base workflow](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

## Core Idea

Instead of just retrieving from raw documents at query time, the LLM **incrementally builds and maintains a persistent wiki** — a structured, interlinked collection of markdown files that sits between you and the raw sources.

When you add a new source, the LLM doesn't just index it for later retrieval. It reads it, extracts the key information, and **integrates it into the existing wiki** — updating entity pages, revising topic summaries, noting where new data contradicts old claims, strengthening the evolving synthesis.

**The key difference:** The wiki is a persistent, compounding artifact. The cross-references are already there. The contradictions have already been flagged. The synthesis already reflects everything you've read.

## Three Layers

1. **Raw sources** (`raw/`) — Your curated collection of source documents. Immutable. LLM reads from them but never modifies them.
2. **The wiki** (`wiki/`) — LLM-generated markdown files. Summaries, entity pages, concept pages, comparisons, synthesis.
3. **The schema** (`AGENTS.md`) — Tells the LLM how the wiki is structured, what the conventions are, and what workflows to follow.

## Quick Start

```bash
# Run the setup script
~/dotfiles/knowledge-base/bin/dotfiles-setup-knowledgebase
```

This will:
1. Install QMD (`npm install -g @tobilu/qmd`)
2. Install ripgrep (`pacman -S ripgrep`)
3. Create the inbox/raw/code/wiki structure
4. Initialize `wiki/index.md` and `wiki/log.md`
5. Configure Syncthing (install + enable service)

## Directory Structure

```
~/Vaults/                    # Main vault (synced via Syncthing)
├── 📥 inbox/                   # DROP NEW THINGS HERE (flat structure)
│                               # Agent organizes when moving to raw/
│
├── 📁 raw/                     # RAW SOURCES (immutable, organized by type)
│   ├── papers/                 # Research papers (author-year-title.pdf)
│   ├── books/                  # Books and long-form content
│   ├── web/                    # Web articles and clippings
│   ├── images/                 # Images and figures
│   ├── audio/                  # Audio files
│   ├── plots/                  # Generated plots from code/
│   └── data/                   # Processed datasets
│
├── 💻 code/                    # JULIA PROJECTS (data analysis & plotting)
│   └── project-name/           # Each is a full Julia project
│       ├── Project.toml
│       ├── src/
│       └── scripts/
│
├── 📚 wiki/                    # LLM-GENERATED WIKI
│   ├── entities/               # People, organizations, tools
│   ├── concepts/               # Core concepts and ideas
│   ├── papers/                 # Paper summaries with links to raw/papers/
│   ├── topics/                 # Topic overviews and syntheses
│   ├── sources/                # Source summaries (books, articles)
│   ├── comparisons/            # Comparison tables and analyses
│   ├── index.md                # CONTENT CATALOG (read first when querying)
│   └── log.md                  # CHRONOLOGICAL LOG (ingests, queries, lint)
│
├── 📅 Daily/                   # Daily notes (YYYY-MM-DD.md)
├── 🔗 MOCs/                    # Maps of Content (navigation hubs)
├── 📎 Attachments/             # Inline images for wiki
└── .templates/                 # Note templates
```

## The Three Operations

### 1. INGEST — Add a New Source

You drop a new source into `inbox/`. The LLM:

1. **Reads** the source (discusses key takeaways with you)
2. **Moves** to organized location in `raw/` (author-year-title pattern)
3. **Creates** summary page in `wiki/papers/` or `wiki/sources/`
4. **Updates** relevant entity pages in `wiki/entities/`
5. **Updates** relevant concept pages in `wiki/concepts/`
6. **Updates** the index (`wiki/index.md`)
7. **Appends** entry to log (`wiki/log.md`)

**A single source might touch 10-15 wiki pages.**

### 2. QUERY — Answer Questions

You ask questions against the wiki. The LLM:

1. **Reads** `wiki/index.md` to find relevant pages
2. **Reads** the relevant wiki pages
3. **Synthesizes** answer with citations
4. **Files good answers back into the wiki** as new pages

**The insight:** Good answers are valuable knowledge too. A comparison you asked for, an analysis, a connection you discovered — these shouldn't disappear into chat history.

### 3. LINT — Health Check

Periodically, the LLM checks the wiki for:

- **Contradictions** between pages
- **Stale claims** superseded by newer sources
- **Orphan pages** with no inbound links
- **Missing pages** for important concepts mentioned but not documented
- **Missing cross-references**
- **Data gaps** that could be filled with web search

## Key Files

### wiki/index.md — Content Catalog

The LLM reads this first when answering queries. Organized by category (entities, concepts, papers, topics, comparisons, sources).

Each entry has:
- Link to the page
- One-line summary
- Optional metadata (date, source count)

```markdown
# Knowledge Base Index

## Papers
- [[papers/attention-is-all-you-need|Attention Is All You Need]] — Transformer architecture (Vaswani et al., 2017)

## Concepts
- [[concepts/self-attention|Self-Attention]] — Mechanism where each position attends to all positions

## Topics
- [[topics/transformers|Transformers]] — Overview of transformer architectures
```

### wiki/log.md — Chronological Log

Append-only record of what happened and when. Each entry starts with a consistent prefix:

```markdown
## [2024-01-15] ingest | Attention Is All You Need
- Source: raw/papers/vaswani-2017-attention.pdf
- Pages created: papers/attention.md, concepts/self-attention.md, entities/vaswani-ashish.md

## [2024-01-14] query | self-attention vs RNNs comparison
- Created: comparisons/rnn-vs-transformer.md

## [2024-01-13] lint | Health check
- Found 2 orphan pages, 1 contradiction
```

**Parseable with Unix tools:**
```bash
# Last 5 entries
grep "^## \[" wiki/log.md | tail -5

# All ingests
grep "ingest |" wiki/log.md
```

## Workflow Examples

### Process a New Paper

```
# 1. You drop paper in inbox
~/Vaults/inbox/random-download.pdf

# 2. Agent identifies and moves to raw/
~/Vaults/raw/papers/vaswani-2017-attention-is-all-you-need.pdf

# 3. Agent creates wiki summary
~/Vaults/wiki/papers/attention-is-all-you-need.md
    (contains: raw: "[[../../raw/papers/vaswani-2017-attention.pdf]]")

# 4. Agent updates related pages
~/Vaults/wiki/concepts/self-attention.md (adds link)
~/Vaults/wiki/entities/vaswani-ashish.md (creates if new)
~/Vaults/wiki/topics/transformers.md (adds link)

# 5. Agent updates index and log
~/Vaults/wiki/index.md (adds entry)
~/Vaults/wiki/log.md (appends ingest entry)
```

### Ask a Question

```
You: "What do I know about neural architecture search?"

Agent:
1. Reads wiki/index.md → finds topics/neural-architecture.md
2. Reads topics/neural-architecture.md
3. Follows links to related papers and concepts
4. Synthesizes answer with citations
5. (If valuable) creates wiki/comparisons/nas-methods.md
6. Updates wiki/log.md with query entry
```

### Data Analysis

```
You: "Analyze my experiment data and plot results"

Agent:
1. Creates ~/Vaults/code/experiment-analysis/
2. Installs dependencies (CairoMakie, DataFrames, CSV)
3. Writes scripts/analyze.jl
4. Runs script → generates plots to raw/plots/
5. Creates ~/Vaults/wiki/data-analysis/experiment.md
   - Links to plots: [[../../raw/plots/results.png]]
   - Links to script: [[../../code/experiment-analysis/scripts/analyze.jl]]
6. Updates wiki/log.md
```

## Principles

### 1. Wiki Never Duplicates Content

Always link to raw/ via Obsidian `[[...]]` links:

```markdown
---
title: Paper Title
raw: "[[../../raw/papers/author-2024-title.pdf]]"
---

## Summary
Brief summary...

## Full Paper
See [[../../raw/papers/author-2024-title.pdf|original PDF]]
```

### 2. File Good Answers Back

When the LLM answers a question, if the answer is valuable and reusable, it creates a new wiki page:

```markdown
<!-- Created after user asked for comparison -->
# RNN vs Transformer

## Comparison Table
| Aspect | RNN | Transformer |
|--------|-----|-------------|
| Parallelism | Sequential | Fully parallel |
| Long dependencies | Vanishing gradients | Attention handles well |

## When to Use Each
- RNNs: Small data, sequential logic required
- Transformers: Large data, parallel hardware available

## Sources
- [[../../raw/papers/vaswani-2017-attention.pdf|Attention Is All You Need]]
```

### 3. Prefer Julia for Analysis

When user asks for data management/analysis:
- Create Julia project in `code/project-name/`
- Use `julia-mcp` MCP server for persistent sessions (avoids TTFX)
- Generate plots to `raw/plots/`
- Create wiki note linking to both plot and script

## Tools

### QMD — Search Engine

[QMD](https://github.com/tobi/qmd) is a local search engine for markdown files with hybrid BM25/vector search and LLM re-ranking.

```bash
# Install
npm install -g @tobilu/qmd

# Search wiki
qmd search "neural architecture search"

# Search specific path
qmd search --path wiki/papers "transformer"
qmd search --path raw/papers "attention"

# Search by tag
qmd search --tag papers
qmd search --tag concepts

# Recent edits
qmd recent --limit 10

# Backlinks
qmd backlinks "Self-Attention"

# Rebuild index
qmd index
```

### ripgrep — Fallback Search

```bash
rg -i "search term" ~/Vaults/wiki
rg -i "search term" ~/Vaults/raw/papers
```

### pdftotext — PDF Extraction

```bash
pdftotext ~/Vaults/raw/papers/paper.pdf - | head -500
```

### Julia — Data Analysis

```bash
# Create project
cd ~/Vaults/code
mkdir experiment-analysis
cd experiment-analysis
julia --project=. -e 'using Pkg; Pkg.add(["Makie", "CairoMakie", "DataFrames"])'
```

## Syncthing Setup

The setup script installs Syncthing, but you must manually configure device pairing:

1. Open Syncthing UI: http://localhost:8384 on each device
2. Get Device ID: Actions → Show ID
3. Add devices on each end
4. Share the `~/Vaults` folder
5. Accept on other devices
6. Set folder path to `~/Vaults`

**Troubleshooting:**
- Devices must be on same network or have global discovery
- Check firewall settings
- Use "local discovery only" for offline LAN sync

## Obsidian Tips

### Web Clipper
Obsidian Web Clipper browser extension converts web articles to markdown. Great for quickly adding sources.

### Download Images Locally
1. Settings → Files and links → Set "Attachment folder path" to `raw/assets/`
2. Settings → Hotkeys → Bind "Download attachments for current file" (e.g., Ctrl+Shift+D)
3. After clipping an article, hit the hotkey to download all images locally

This lets the LLM view and reference images directly instead of relying on URLs.

### Graph View
Obsidian's graph view shows the shape of your wiki — what's connected, which pages are hubs, which are orphans.

### Marp
Marp is a markdown-based slide deck format. Useful for generating presentations directly from wiki content.

### Dataview
Dataview plugin runs queries over page frontmatter. If your LLM adds YAML frontmatter to wiki pages (tags, dates, source counts), Dataview can generate dynamic tables and lists.

## Templates

The setup script creates templates in `~/Vaults/.templates/`:

**Paper summary:**
```markdown
---
date: {{date:YYYY-MM-DD}}
tags: [paper, ml]
status: unread
raw: "[[../../raw/papers/FILENAME]]"
---

# Title

## Metadata
- **Authors:**
- **Venue:**
- **Year:**
- **Raw:** See link above

## Summary

## Key Contributions

## Related
- [[concept-a]]
```

**Data analysis:**
```markdown
---
date: {{date:YYYY-MM-DD}}
tags: [analysis, julia]
status: completed
---

# Analysis Name

## Objective

## Data Source
[[../../raw/data/FILENAME|Raw data]]

## Method
[[../../code/PROJECT/scripts/SCRIPT.jl|Source code]]

## Results
![Plot 1](../../raw/plots/plot1.png)

## Key Findings

## Related
```

## OpenClaw Skills

- **knowledge-base** — Search wiki, read notes, create new notes, check inbox
- **knowledge-base-ingest** — Process inbox → raw + wiki (full INGEST workflow)
- **knowledge-base-analysis** — Create Julia projects for data analysis

## Why This Works

The tedious part of maintaining a knowledge base is not the reading or the thinking — it's the bookkeeping. Updating cross-references, keeping summaries current, noting when new data contradicts old claims, maintaining consistency across dozens of pages.

Humans abandon wikis because the maintenance burden grows faster than the value. **LLMs don't get bored, don't forget to update a cross-reference, and can touch 15 files in one pass.** The wiki stays maintained because the cost of maintenance is near zero.

The human's job is to curate sources, direct the analysis, ask good questions, and think about what it all means. The LLM's job is everything else.

## References

- [Andrej Karpathy's LLM Wiki Guide](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [QMD - Query Markdown Database](https://github.com/tobi/qmd)
- [Syncthing](https://syncthing.net/)
- [Obsidian](https://obsidian.md/)
- [Marp](https://marp.app/)
