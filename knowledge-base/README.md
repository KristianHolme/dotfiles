# Knowledge Base System

Personal knowledge management system based on Andrej Karpathy's LLM Knowledge Base workflow.

## Overview

This system implements a two-tier knowledge architecture:

- **`~/raw/`** - Unstructured ingestion (PDFs, web articles, notes, screenshots)
- **`~/Knowledge/wiki/`** - Compiled, interlinked knowledge base (Obsidian vault)

The workflow is designed to leverage LLMs for automatically processing raw materials into structured, searchable knowledge.

## Quick Start

```bash
# Run the setup script (idempotent - safe to run multiple times)
~/dotfiles/knowledge-base/bin/dotfiles-setup-knowledgebase
```

This will:
1. Install required tools (QMD via npm, ripgrep via pacman)
2. Create the directory structure
3. Configure Syncthing for cross-device sync
4. Set up note templates
5. Install OpenClaw skills

## Directory Structure

```
~/Knowledge/                    # Main vault (synced via Syncthing)
├── 📥 Inbox/                  # New notes, fleeting ideas
├── 📚 wiki/                   # Compiled knowledge
│   ├── concepts/              # Core concepts and definitions
│   ├── papers/                # Paper summaries with backlinks
│   ├── people/                # People profiles
│   ├── projects/              # Project documentation
│   ├── topics/                # Topic overviews
│   └── index.md               # Main entry point
├── 📅 Daily/                  # Daily notes (YYYY-MM-DD.md)
├── 🔗 MOCs/                   # Maps of Content (navigation pages)
├── 📎 Attachments/            # Images, PDFs, external files
├── 🏷️ Tags.md                 # Tag directory
└── .templates/                # Note templates

~/raw/                         # Raw data ingestion (synced separately)
├── papers/                    # PDF papers
├── books/                     # Book highlights/notes
├── web/                       # Web article saves (markdown)
├── code/                      # Code snippets, repos
├── images/                    # Screenshots, diagrams
├── audio/                     # Podcasts, voice memos
├── processed/                 # Already-processed files
└── index.md                   # Knowledge base index (in raw/)
```

## Components

### 1. QMD - Fast Search

QMD (by Tobi) provides lightning-fast full-text search over your vault using ripgrep.

```bash
qmd search "neural architecture search"    # Search notes
qmd search --tag papers                     # Search by tag
qmd index                                   # Rebuild search index
qmd recent                                  # Recently modified notes
qmd backlinks "Concept Note"                # Find backlinks
```

Configuration: `~/.config/qmd/config.yaml`

Install via npm: `npm install -g @tobilu/qmd`

### 2. Syncthing - Cross-Device Sync

Peer-to-peer synchronization across your devices.

- Work laptop
- Personal laptop
- Phone (Android)

Configure at: http://localhost:8384

### 3. OpenClaw Skills

Two skills for knowledge base interaction:

- **knowledge-base** - Search and use the knowledge base
- **knowledge-base-ingest** - Process raw materials into the wiki

## Workflow

### Daily Usage

1. **Capture** - Add content to `~/raw/` (papers, web articles, notes)
2. **Process** - Run the ingest skill to compile into wiki
3. **Search** - Use QMD to find information
4. **Connect** - Create backlinks between related concepts

### From Raw to Wiki

```
~/raw/papers/paper.pdf
    ↓ [LLM Agent processes]
~/Knowledge/wiki/papers/paper-summary.md
    ↓ [Manual refinement + backlinks]
Connected knowledge graph in Obsidian
```

## Tools & Usage

### QMD Commands

```bash
# Search for a topic
qmd search "neural architecture search"

# Search with context
qmd search --context 3 "attention mechanism"

# Search by tag
qmd search --tag papers

# List recently modified
qmd recent --limit 10

# Show backlinks
qmd backlinks "Attention Mechanism"

# Rebuild index (if needed)
qmd index
```

### File Operations

```bash
# Create new note
cat > ~/Knowledge/wiki/papers/new-paper.md << 'EOF'
---
date: 2024-01-01
tags: [paper]
---
# Title
...
EOF

# Read existing note
cat ~/Knowledge/wiki/concepts/transformer.md

# Edit note
$EDITOR ~/Knowledge/wiki/concepts/transformer.md
```

## Templates

Templates are stored in `~/Knowledge/.templates/`:

- **paper.md** - Academic paper summaries
- **concept.md** - Concept definitions
- **project.md** - Project documentation

## Configuration

### Environment Variables

```bash
export KNOWLEDGE_VAULT_PATH="$HOME/Knowledge"
export KNOWLEDGE_RAW_PATH="$HOME/raw"
```

### Syncthing Ignore Patterns

The `.stignore` file excludes:
- `.obsidian/` - Obsidian config (device-specific)
- Large media files
- Build artifacts
- Git directories

## References

- [Andrej Karpathy's LLM Knowledge Base post](https://twitter.com/karpathy/status/1772925336763494570)
- [QMD - Query Markdown Database](https://github.com/tobi/qmd)
- [Syncthing](https://syncthing.net/)

## License

Part of the dotfiles repository.
