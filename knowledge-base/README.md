# Knowledge Base System

Personal knowledge management system based on Andrej Karpathy's LLM Knowledge Base workflow.

## Overview

Four-tier knowledge architecture (inside `~/Knowledge/` vault):

- **`inbox/`** - Unprocessed new items (you drop things here)
- **`raw/`** - Processed/organized raw materials (agent moves from inbox)
- **`code/`** - Julia projects for data analysis and plotting
- **`wiki/`** - Compiled knowledge (links to raw/ and code/ via Obsidian `[[...]]` links)

## Quick Start

```bash
# Run the setup script
~/dotfiles/knowledge-base/bin/dotfiles-setup-knowledgebase
```

This will:
1. Install QMD (`npm install -g @tobilu/qmd`)
2. Install ripgrep (`pacman -S ripgrep`)
3. Create the inbox/raw/code/wiki structure
4. Configure Syncthing (install + enable service)
5. Set up templates

## Syncthing Setup (Manual Steps Required)

The setup script installs and starts Syncthing, but **you must manually configure device pairing**:

### Step 1: Open Syncthing UI
On each device, open: http://localhost:8384

### Step 2: Get Device ID
On each device, go to **Actions → Show ID** and copy the long device ID.

### Step 3: Add Devices
1. On your primary device, click **Add Remote Device**
2. Enter the Device ID from your other device
3. Give it a name (e.g., "laptop", "phone")
4. Click **Save**
5. Repeat on the other device (add the primary device ID)

### Step 4: Share the Knowledge Folder
1. On your primary device, in the Folders section, click **Add Folder**
2. **Folder ID**: `knowledge-base`
3. **Folder Path**: `~/Knowledge`
4. **Sharing**: Check the box for your other device(s)
5. Click **Save**

### Step 5: Accept on Other Devices
On each other device:
1. You'll see a prompt asking to add the "knowledge-base" folder
2. Click **Add**
3. Set **Folder Path** to `~/Knowledge`
4. Click **Save**

### Step 6: Verify Sync
Drop a file in `~/Knowledge/inbox/` on one device. It should appear on the other device within seconds.

**Troubleshooting:**
- Devices must be on the same network (or have internet access for global discovery)
- Check firewall settings if devices don't see each other
- Use "local discovery only" for offline LAN sync

## Directory Structure

```
~/Knowledge/                    # Main vault (synced via Syncthing)
├── 📥 inbox/                   # DROP NEW THINGS HERE (flat - any file type)
│                               # Agent organizes when moving to raw/
│
├── 📁 raw/                     # PROCESSED/ORGANIZED (agent moves here)
│   ├── papers/                 # Organized papers from inbox
│   ├── books/                  # Organized books
│   ├── web/                    # Organized web saves
│   ├── images/                 # Organized images
│   ├── audio/                  # Organized audio
│   ├── plots/                  # Generated plots from code/
│   └── data/                   # Processed datasets
│
├── 💻 code/                    # JULIA PROJECTS (data analysis & plots)
│   ├── analysis-a/             # Julia project for analysis A
│   │   ├── Project.toml
│   │   ├── src/AnalysisA.jl
│   │   └── scripts/plot_results.jl
│   └── experiment-b/           # Julia project for experiment B
│
├── 📚 wiki/                    # COMPILED KNOWLEDGE
│   ├── concepts/               # Core concepts
│   ├── papers/                 # Paper summaries with links
│   ├── people/                 # People profiles
│   ├── projects/               # Project docs
│   ├── topics/                 # Topic overviews
│   ├── data-analysis/          # Data analysis summaries
│   │   └── analysis-name.md    # Links to plots AND scripts
│   └── index.md                # Main entry point
│
├── 📅 Daily/                   # Daily notes (YYYY-MM-DD.md)
├── 🔗 MOCs/                    # Maps of Content (navigation)
├── 📎 Attachments/             # Inline images for wiki
└── .templates/                 # Note templates
```

## Workflow

### 1. Capture (You)
```
# Drop anything in inbox (flat structure - no organizing needed)
~/Knowledge/inbox/random-paper.pdf
~/Knowledge/inbox/article-from-web.md
~/Knowledge/inbox/screenshot.png
~/Knowledge/inbox/voice-memo.m4a
```

### 2. Process (Agent)
```
# Agent finds items in inbox
# 1. Identifies file type and content
# 2. Moves to organized location in raw/:
#    - PDFs → raw/papers/author-year-title.pdf
#    - Web articles → raw/web/site-date-title.md
#    - Images → raw/images/date-description.png
# 3. Creates wiki note with link to raw/
# 4. Empty inbox for this item
```

### 3. Data Analysis (Agent + Julia)
```
# User asks for data analysis/plots
# 1. Agent creates Julia project in code/project-name/
# 2. Script generates plots to raw/plots/
# 3. Agent creates wiki/data-analysis/project.md linking to:
#    - Plots: [[../../raw/plots/figure.png]]
#    - Script: [[../../code/project-name/scripts/plot.jl]]
```

### 4. Use (You + Agent)
```
# Search wiki for info
qmd search "neural architecture search"

# Follow link to raw paper
# In wiki/papers/paper-summary.md:
#   raw: "[[../../raw/papers/attention-is-all-you-need.pdf]]"
# Click link to open original PDF
```

## Key Principles

**1. Wiki never duplicates raw content** — it links to it:

```markdown
---
title: Attention Is All You Need
raw: "[[../../raw/papers/attention-is-all-you-need.pdf]]"
---

# Attention Is All You Need

## Summary
Brief summary here...

## Full Paper
See [[../../raw/papers/attention-is-all-you-need.pdf|original paper]]
```

**2. Data analysis lives in code/, outputs to raw/, documented in wiki/**:

```markdown
---
title: Experiment Results Analysis
date: 2024-01-15
tags: [analysis, julia]
---

# Experiment Results

## Plots
![Results](../../raw/plots/experiment-results.png)

## Script
Analysis performed by [[../../code/experiment-analysis/scripts/plot.jl|this script]]

## Summary
Key findings from the analysis...
```

## Components

### 1. QMD - Fast Search

```bash
qmd search "neural architecture search"  # Search wiki
qmd search --path raw/papers "transformer"  # Search raw papers
qmd search --tag papers                   # All paper notes
qmd index                                 # Rebuild index
```

Install: `npm install -g @tobilu/qmd`

### 2. Julia - Data Analysis

When user asks for data management/analysis:
- Create Julia project in `code/project-name/`
- Use `julia-mcp` MCP server for persistent sessions (avoids TTFX)
- Generate plots to `raw/plots/`
- Create wiki note linking to both plot and script

Example:
```bash
# Create Julia project
cd ~/Knowledge/code
mkdir experiment-analysis
cd experiment-analysis
julia --project=. -e 'using Pkg; Pkg.add(["Makie", "CairoMakie", "DataFrames", "CSV"])'

# Create script
cat > scripts/plot_results.jl << 'EOF'
using CairoMakie, DataFrames, CSV

data = CSV.read("../../raw/data/experiment.csv", DataFrame)

fig = Figure()
ax = Axis(fig[1, 1], title="Results")
scatter!(ax, data.x, data.y)

save("../../raw/plots/experiment-results.png", fig)
EOF
```

### 3. Syncthing - Cross-Device Sync

- Work laptop
- Personal laptop
- Phone (Android)

Configure: http://localhost:8384

### 4. OpenClaw Skills

- **knowledge-base** - Search wiki, read notes, create new notes
- **knowledge-base-ingest** - Process inbox → raw + wiki
- **knowledge-base-analysis** - Create Julia projects for data analysis

## Ingest Skill Workflow

```
~/Knowledge/inbox/papers/paper.pdf
    ↓ [Agent detects new item]
    ↓ [Reads and summarizes]
    ↓ [Moves to organized location]
~/Knowledge/raw/papers/author-year-title.pdf
    ↓ [Creates wiki note with link]
~/Knowledge/wiki/papers/paper-summary.md
    (contains: raw: "[[../../raw/papers/author-year-title.pdf]]")
```

## Data Analysis Workflow

```
User: "Analyze my experiment data and plot results"

→ Agent creates code/experiment-analysis/
   → Project.toml with dependencies
   → scripts/analyze.jl
   
→ Script runs (via julia-mcp or direct)
   → Reads data from raw/data/
   → Generates plots to raw/plots/
   
→ Agent creates wiki/data-analysis/experiment.md
   → Links to plot: [[../../raw/plots/result.png]]
   → Links to script: [[../../code/experiment-analysis/scripts/analyze.jl]]
   → Summary of findings

Result: Reproducible analysis with full provenance
```

## Templates

**Paper summary template** (`~/Knowledge/.templates/paper.md`):

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

**Data analysis template** (`~/Knowledge/.templates/data-analysis.md`):

```markdown
---
date: {{date:YYYY-MM-DD}}
tags: [analysis, julia]
status: completed
---

# Analysis Name

## Objective
What we analyzed and why

## Data Source
[[../../raw/data/FILENAME|Raw data]]

## Method
Analysis performed by [[../../code/PROJECT/scripts/SCRIPT.jl|this script]]

## Results
![Plot 1](../../raw/plots/plot1.png)
![Plot 2](../../raw/plots/plot2.png)

## Key Findings
- Finding 1
- Finding 2

## Related
- [[paper-reference]]
- [[concept-reference]]
```

## References

- [Andrej Karpathy's LLM Knowledge Base thread](https://twitter.com/karpathy/status/1772925336763494570)
- [QMD - Query Markdown Database](https://github.com/tobi/qmd)
- [Syncthing](https://syncthing.net/)
