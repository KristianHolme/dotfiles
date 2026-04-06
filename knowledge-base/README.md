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
1. Install required tools (QMD, obsidian-cli, ripgrep)
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

~/raw/                         # Raw data ingestion
├── papers/                    # PDF papers
├── books/                     # Book highlights/notes
├── web/                       # Web article saves
├── code/                      # Code snippets, repos
├── images/                    # Screenshots, diagrams
├── audio/                     # Podcasts, voice memos
└── processed/                 # Already-processed files
```

## Components

### 1. QMD - Fast Search

QMD (by Tobi) provides lightning-fast full-text search over your vault using ripgrep.

```bash
qmd search "neural architecture search"    # Search notes
qmd search --tag papers                     # Search by tag
qmd index                                   # Rebuild search index
qmd recent                                  # Recently modified notes
```

Configuration: `~/.config/qmd/config.yaml`

### 2. obsidian-cli - Vault Management

Command-line interface to Obsidian vaults.

```bash
obsidian-cli ls                              # List vaults
obsidian-cli open ~/Knowledge                # Open vault
obsidian-cli new "Paper Notes"               # Create note from template
obsidian-cli daily                           # Open daily note
```

Configuration: `~/.config/obsidian-cli/config.json`

### 3. Syncthing - Cross-Device Sync

Peer-to-peer synchronization across all your devices.

- Work laptop
- Personal laptop
- Phone (Android)
- iPad (via Möbius Sync)

Configure at: http://localhost:8384

### 4. OpenClaw Skills

Two skills for knowledge base interaction:

- **knowledge-base** - Search and use the knowledge base
- **knowledge-base-ingest** - Process raw materials into the wiki

## Workflow

### Daily Usage

1. **Capture** - Add content to `~/raw/` (papers, web articles, notes)
2. **Process** - Run the ingest skill to compile into wiki
3. **Search** - Use QMD or the knowledge-base skill to find information
4. **Connect** - Create backlinks between related concepts in Obsidian

### From Raw to Wiki

```
~/raw/papers/paper.pdf
    ↓ [LLM Agent processes]
~/Knowledge/wiki/papers/paper-summary.md
    ↓ [Manual refinement + backlinks]
Connected knowledge graph in Obsidian
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
- [obsidian-cli](https://github.com/Bip901/obsidian-cli)
- [Syncthing](https://syncthing.net/)

## License

Part of the dotfiles repository.
