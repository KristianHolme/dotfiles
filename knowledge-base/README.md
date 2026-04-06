# Knowledge Base System

Personal knowledge management system based on Andrej Karpathy's LLM Knowledge Base workflow.

## Overview

Three-tier knowledge architecture (inside `~/Knowledge/` vault):

- **`inbox/`** - Unprocessed new items (you drop things here)
- **`raw/`** - Processed/organized raw materials (agent moves from inbox)
- **`wiki/`** - Compiled knowledge (links to raw/ via Obsidian `[[...]]` links)

## Quick Start

```bash
# Run the setup script
~/dotfiles/knowledge-base/bin/dotfiles-setup-knowledgebase
```

This will:
1. Install QMD (`npm install -g @tobilu/qmd`)
2. Install ripgrep (`pacman -S ripgrep`)
3. Create the inbox/raw/wiki structure
4. Configure Syncthing
5. Set up templates

## Directory Structure

```
~/Knowledge/                    # Main vault (synced via Syncthing)
├── 📥 inbox/                   # DROP NEW THINGS HERE
│   ├── papers/                 # New PDFs, papers
│   ├── books/                  # Book notes
│   ├── web/                    # Web article saves
│   ├── code/                   # Code snippets
│   ├── images/                 # Screenshots, diagrams
│   └── audio/                  # Voice memos
│
├── 📁 raw/                     # PROCESSED/ORGANIZED (agent moves here)
│   ├── papers/                 # Organized papers from inbox
│   ├── books/                  # Organized books
│   ├── web/                    # Organized web saves
│   ├── code/                   # Organized code
│   ├── images/                 # Organized images
│   └── audio/                  # Organized audio
│
├── 📚 wiki/                    # COMPILED KNOWLEDGE (links to raw/)
│   ├── concepts/               # Core concepts (link to raw/papers/)
│   ├── papers/                 # Paper summaries with links
│   ├── people/                 # People profiles
│   ├── projects/               # Project docs
│   ├── topics/                 # Topic overviews
│   └── index.md                # Main entry point
│
├── 📅 Daily/                   # Daily notes (YYYY-MM-DD.md)
├── 🔗 MOCs/                    # Maps of Content (navigation)
├── 📎 Attachments/             # Inline images for wiki notes
└── .templates/                 # Note templates
```

## Workflow

### 1. Capture (You)
```
# Drop new paper in inbox
~/Knowledge/inbox/papers/new-paper.pdf
```

### 2. Process (Agent)
```
# Agent finds items in inbox
# 1. Reads the paper
# 2. Moves PDF to raw/papers/organized-name.pdf
# 3. Creates wiki/papers/paper-summary.md with link:
#    raw: "[[../../raw/papers/organized-name.pdf]]"
# 4. Empty inbox for this item
```

### 3. Use (You + Agent)
```
# Search wiki for info
qmd search "neural architecture search"

# Follow link to raw paper
# In wiki/papers/paper-summary.md:
#   raw: "[[../../raw/papers/attention-is-all-you-need.pdf]]"
# Click link to open original PDF
```

## Key Principle

**Wiki never duplicates raw content** — it links to it:

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

## Components

### 1. QMD - Fast Search

```bash
qmd search "neural architecture search"  # Search wiki
qmd search --path raw/papers "transformer"  # Search raw papers
qmd search --tag papers                   # All paper notes
qmd index                                 # Rebuild index
```

Install: `npm install -g @tobilu/qmd`

### 2. Syncthing - Cross-Device Sync

- Work laptop
- Personal laptop
- Phone (Android)

Configure: http://localhost:8384

### 3. OpenClaw Skills

- **knowledge-base** - Search wiki, read notes, create new notes
- **knowledge-base-ingest** - Process inbox → raw + wiki

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

## References

- [Andrej Karpathy's LLM Knowledge Base thread](https://twitter.com/karpathy/status/1772925336763494570)
- [QMD - Query Markdown Database](https://github.com/tobi/qmd)
- [Syncthing](https://syncthing.net/)
