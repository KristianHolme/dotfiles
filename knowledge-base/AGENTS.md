# AGENTS.md - Knowledge Base

Personal knowledge management system based on Andrej Karpathy's LLM Knowledge Base workflow.

## Core Architecture (Three Layers)

1. **Raw sources** (`raw/`) — Immutable curated documents. LLM reads, never modifies.
2. **The wiki** (`wiki/`) — LLM-generated markdown. Summaries, entity pages, concept pages, synthesis.
3. **The schema** (this file) — Conventions and workflows for the LLM to maintain the wiki.

## Directory Structure

```
~/Vaults/Wiki/
├── 📥 inbox/        # DROP NEW ITEMS HERE (you add, flat structure)
├── 📁 raw/          # ORGANIZED RAW SOURCES (LLM moves here from inbox)
│   ├── papers/      # Research papers
│   ├── books/       # Books and long-form content
│   ├── web/         # Web articles and clippings
│   ├── images/      # Images and figures
│   ├── audio/       # Audio files
│   ├── plots/       # Generated plots from code/
│   └── data/        # Processed datasets
├── 💻 code/         # JULIA PROJECTS (data analysis & plotting)
│   └── project-name/
│       ├── Project.toml
│       └── scripts/
├── 📚 wiki/         # LLM-GENERATED KNOWLEDGE BASE
│   ├── entities/    # People, organizations, tools
│   ├── concepts/    # Core concepts and ideas
│   ├── papers/      # Paper summaries with links to raw/papers/
│   ├── topics/      # Topic overviews and syntheses
│   ├── sources/     # Source summaries (books, articles)
│   ├── comparisons/ # Comparison tables and analyses
│   ├── index.md     # CONTENT CATALOG (read this first when querying)
│   └── log.md       # CHRONOLOGICAL LOG (ingests, queries, lint)
├── 📅 Daily/        # Daily notes (YYYY-MM-DD.md)
└── 🔗 MOCs/         # Maps of Content (navigation hubs)
```

## The Three Operations

### 1. INGEST — Add Source to Knowledge Base

When a new source arrives in `inbox/`:

**Workflow:**
1. **Read** the source (discuss key takeaways with user)
2. **Move** to organized location in `raw/` (rename with author-year-title pattern)
3. **Create** summary page in `wiki/sources/` or `wiki/papers/`
4. **Update** relevant entity pages in `wiki/entities/`
5. **Update** relevant concept pages in `wiki/concepts/`
6. **Update** the index (`wiki/index.md`)
7. **Append** entry to log (`wiki/log.md`)
8. **Update** QMD index (`qmd update && qmd embed`) - makes content searchable

**Example:**
```
User drops: inbox/confusing-name.pdf
    ↓
LLM reads PDF, extracts: Vaswani et al., 2017, "Attention Is All You Need"
    ↓
Move to: raw/papers/vaswani-2017-attention-is-all-you-need.pdf
    ↓
Create: wiki/papers/attention-is-all-you-need.md
    - Summary
    - Key contributions
    - Links to: raw/papers/vaswani-2017-attention-is-all-you-need.pdf
    ↓
Update: wiki/concepts/self-attention.md
    - Add link to new paper
    - Update description if needed
    ↓
Update: wiki/entities/vaswani-ashish.md (if doesn't exist, create)
    ↓
Update: wiki/index.md (add entry under "Papers")
    ↓
Append to: wiki/log.md
    ## [2024-01-15] ingest | Attention Is All You Need
    - Source: raw/papers/vaswani-2017-attention-is-all-you-need.pdf
    - Wiki pages created/updated: papers/attention-is-all-you-need.md, concepts/self-attention.md, entities/vaswani-ashish.md
    ↓
Update QMD index:
    qmd update && qmd embed
    (makes content searchable via qmd query/vsearch)
```

### 2. QUERY — Answer Questions Using the Wiki

When user asks a question:

**Workflow:**
1. **Read** `wiki/index.md` to find relevant pages
2. **Read** the relevant wiki pages
3. **Synthesize** answer with citations (format: markdown, table, slides, chart)
4. **File valuable answers back into wiki** (create new pages if useful)

**Key Insight:** Good answers are knowledge too. File them back.

**Example:**
```
User asks: "Compare self-attention vs RNNs"
    ↓
LLM reads index.md → finds concepts/self-attention.md, concepts/rnn.md
    ↓
LLM reads those pages + their linked sources
    ↓
LLM creates answer + comparison table
    ↓
(Valuable answer → file to wiki/comparisons/self-attention-vs-rnn.md)
    ↓
Append to: wiki/log.md
    ## [2024-01-15] query | self-attention vs RNNs comparison
    - Created: wiki/comparisons/self-attention-vs-rnn.md
```

### 3. LINT — Health Check the Wiki

Periodically (or on request), check for:

- **Contradictions** between pages
- **Stale claims** superseded by newer sources
- **Orphan pages** with no inbound links
- **Missing pages** for important concepts mentioned but not documented
- **Missing cross-references** that should exist
- **Data gaps** that could be filled with web search

**Example:**
```
User asks: "Lint the wiki"
    ↓
LLM scans wiki for issues
    ↓
Finds: wiki/papers/old-paper.md claims X, but wiki/papers/new-paper.md claims not-X
    ↓
Reports contradiction, suggests resolution
    ↓
Append to: wiki/log.md
    ## [2024-01-15] lint | Found 3 issues
    - Contradiction: X in old-paper.md vs not-X in new-paper.md
    - Orphan: wiki/concepts/forgotten-concept.md (no inbound links)
    - Missing: wiki/papers/transformer-xl.md references "relative positional encoding" but no concept page exists
```

## Key Principles

### 1. Never Duplicate Content

**Wiki links to raw/, never copies:**

```markdown
---
title: Attention Is All You Need
date: 2024-01-15
tags: [paper, transformers, nlp]
raw: "[[../../raw/papers/vaswani-2017-attention.pdf]]"
---

# Attention Is All You Need

## Summary
Brief summary here...

## Full Paper
See [[../../raw/papers/vaswani-2017-attention.pdf|original PDF]]
```

### 2. Prefer Julia for Data Analysis

When user asks for data analysis/plots:
- Create Julia project in `code/project-name/`
- Use `julia-mcp` MCP server for persistent sessions (avoids TTFX)
- Generate plots to `raw/plots/`
- Create wiki note linking to both plot and script

```markdown
---
title: Experiment Results Analysis
date: 2024-01-15
tags: [analysis, julia]
---

# Analysis Results

## Plots
![Results](../../raw/plots/experiment-results.png)

## Script
Analysis performed by [[../../code/experiment-analysis/scripts/plot.jl|this script]]

## Data
[[../../raw/data/experiment.csv|Raw data]]
```

### 3. File Good Answers Back

When answering questions, if the answer is valuable and reusable:
- Create a new wiki page (in appropriate folder)
- Include citations to sources
- Update index.md
- Log it

## Critical Files

### wiki/index.md — Content Catalog

The LLM reads this first when answering queries. Structure:

```markdown
# Knowledge Base Index

## Papers
- [[papers/attention-is-all-you-need|Attention Is All You Need]] — Transformer architecture (Vaswani et al., 2017)
- [[papers/gpt3|Language Models are Few-Shot Learners]] — GPT-3 (Brown et al., 2020)

## Concepts
- [[concepts/self-attention|Self-Attention]] — Mechanism where each position attends to all positions
- [[concepts/transformer|Transformer]] — Architecture using self-attention

## Entities
- [[entities/vaswani-ashish|Ashish Vaswani]] — Co-author of Attention Is All You Need

## Topics
- [[topics/nlp|Natural Language Processing]] — Overview of NLP field
- [[topics/neural-architecture|Neural Architecture Search]] — Methods for finding optimal architectures

## Comparisons
- [[comparisons/rnn-vs-transformer|RNN vs Transformer]] — Architecture comparison

## Sources
- [[sources/llm-wiki-guide|Karpathy's LLM Wiki Guide]] — Original pattern documentation
```

### wiki/log.md — Chronological Record

Append-only log. Each entry starts with consistent prefix for easy parsing:

```markdown
# Knowledge Base Log

## [2024-01-15] ingest | Attention Is All You Need
- Source: raw/papers/vaswani-2017-attention.pdf
- Pages created: papers/attention-is-all-you-need.md, concepts/self-attention.md, entities/vaswani-ashish.md
- Pages updated: index.md

## [2024-01-14] query | self-attention vs RNNs
- Created: comparisons/rnn-vs-transformer.md
- Answer format: comparison table

## [2024-01-13] lint | Health check
- Found 2 orphan pages: concepts/abandoned.md, entities/unknown.md
- Found 1 contradiction: X in papers/old.md vs not-X in papers/new.md
- Actions: linked orphans, flagged contradiction for review
```

**Parseable format for Unix tools:**
```bash
# Last 5 entries
grep "^## \[" wiki/log.md | tail -5

# All ingests
grep "ingest |" wiki/log.md

# All queries from January
grep "^## \[2024-01" wiki/log.md | grep "query"
```

## Search with QMD

QMD is the primary search tool for the knowledge base.

### Installation
```bash
npm install -g @tobilu/qmd
```

### Basic Usage

```bash
# Search entire wiki
qmd search "neural architecture search"

# Search specific path
qmd search --path wiki/papers "transformer"
qmd search --path raw/papers "attention mechanism"

# Search by tag
qmd search --tag papers
qmd search --tag concepts

# Recent edits
qmd recent --limit 10

# Backlinks (what links to this page)
qmd backlinks "Self-Attention"

# Rebuild index (after major changes)
qmd index
```

### Search Strategies

**Finding a specific paper:**
```bash
# Search wiki summaries
qmd search "attention is all you need"

# If not found, search raw papers
qmd search --path raw/papers "vaswani"

# List all papers by tag
qmd search --tag papers
```

**Exploring a concept:**
```bash
# Find the concept page
qmd search "self-attention"
cat wiki/concepts/self-attention.md

# Find what links to it (related concepts/papers)
qmd backlinks "Self-Attention"

# Search for mentions in papers
qmd search --path wiki/papers "self-attention"
```

**Checking recent activity:**
```bash
# Recent wiki edits
qmd recent --limit 20

# Parse log for recent ingests
grep "ingest |" wiki/log.md | tail -5

# Today's work
DAILY="$HOME/Knowledge/Daily/$(date +%Y-%m-%d).md"
[[ -f "$DAILY" ]] && cat "$DAILY"
```

### Fallback: ripgrep

If QMD is unavailable:
```bash
rg -i "search term" ~/Vaults/Wiki/wiki
rg -i "search term" ~/Vaults/Wiki/raw/papers
rg -C 3 "term" ~/Vaults/Wiki/wiki/papers/
```

## File Naming Conventions

### In raw/
- **Papers:** `author-year-title-keywords.pdf` → `vaswani-2017-attention-is-all-you-need.pdf`
- **Web articles:** `site-date-title.md` → `karpathy-2024-llm-knowledge-base-guide.md`
- **Books:** `author-year-book-title.pdf`
- **Plots:** `analysis-name-description.png`
- **Data:** `experiment-name.csv`

### In code/
- **Projects:** `analysis-name/`, `experiment-name/`
- Each has `Project.toml`, `src/`, `scripts/`

### In wiki/
- **Papers:** `paper-title.md` (kebab-case)
- **Concepts:** `concept-name.md`
- **Entities:** `person-name.md` or `org-name.md`
- **Topics:** `topic-name.md`
- **Comparisons:** `x-vs-y.md`

## Julia MCP Server

When doing data analysis:
1. Use `julia-mcp` MCP server for persistent Julia sessions
2. This avoids TTFX (time to first execution) issues
3. Iterate quickly without recompiling

Example workflow:
```bash
# Agent creates project
cd ~/Vaults/Wiki/code
mkdir experiment-analysis
cd experiment-analysis
julia --project=. -e 'using Pkg; Pkg.add(["Makie", "CairoMakie", "DataFrames", "CSV"])'

# Agent writes script
# Agent runs via julia-mcp
# Script generates plots to raw/plots/
# Agent creates wiki note linking to both
```

## Syncthing

The entire `~/Vaults/Wiki` folder syncs across devices:
- Work laptop
- Personal laptop
- Phone (Android)

Web UI: http://localhost:8384

## When User Asks

- **"What's in my inbox?"** → `find ~/Vaults/Wiki/inbox -type f`
- **"Process my inbox"** → INGEST operation
- **"Search for..."** → `qmd search "query"`
- **"Create note for..."** → Create in wiki/, update index.md, log it
- **"Analyze this data..."** → Create Julia project, generate plots, link in wiki
- **"Lint the wiki"** → LINT operation
- **"What was I working on?"** → Read log.md, check Daily/ notes, qmd recent

## Response Templates

### After INGEST:
```
📥 INGEST Complete
==================
Source: raw/papers/vaswani-2017-attention.pdf

Pages Created:
✓ wiki/papers/attention-is-all-you-need.md
✓ wiki/concepts/self-attention.md
✓ wiki/entities/vaswani-ashish.md

Pages Updated:
✓ wiki/index.md

Log:
✓ wiki/log.md updated
```

### After QUERY:
```
📋 QUERY Answered
=================
Question: "Compare self-attention vs RNNs"

Sources Consulted:
- wiki/concepts/self-attention.md
- wiki/concepts/rnn.md
- raw/papers/vaswani-2017-attention.pdf

Answer:
[Answer with citations]

Filing:
✓ Created wiki/comparisons/self-attention-vs-rnn.md (valuable answer)
✓ Updated wiki/index.md
✓ Updated wiki/log.md
```

### After LINT:
```
🧹 LINT Complete
================
Issues Found: 3

⚠️ Contradiction: wiki/papers/old.md claims X, wiki/papers/new.md claims not-X
⚠️ Orphan: wiki/concepts/forgotten.md (no inbound links)
⚠️ Missing: wiki/papers/transformer-xl.md references "relative positional encoding" with no concept page

Recommendations:
1. Review contradiction between old and new paper
2. Link forgotten.md from relevant topic pages
3. Create concepts/relative-positional-encoding.md

Log:
✓ wiki/log.md updated
```
