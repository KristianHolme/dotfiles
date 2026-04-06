---
name: knowledge-base
description: Search and interact with personal knowledge base (Obsidian vault with QMD)
metadata:
  {
    "openclaw":
      {
        "emoji": "🧠",
        "requires": { "anyBins": ["qmd", "rg"] },
        "install":
          [
            {
              "id": "qmd",
              "kind": "node",
              "package": "@tobilu/qmd",
              "bins": ["qmd"],
              "label": "Install QMD (Query Markdown Database)",
            },
            {
              "id": "ripgrep",
              "kind": "pacman",
              "package": "ripgrep",
              "bins": ["rg"],
              "label": "Install ripgrep",
            },
          ],
      },
  }
---

# Knowledge Base Skill

Search and interact with your personal knowledge base (Obsidian vault + QMD).

## Purpose

This skill enables you to:
- Search your knowledge base using fast full-text search (QMD)
- Find related concepts via backlinks
- Create new notes from templates (via file operations)
- Read and edit existing notes
- Answer questions based on your knowledge base content

## Configuration

Default vault path: `~/Knowledge`
Set via: `knowledge-base.vault_path` in OpenClaw config

## Tools Available

### 1. QMD - Fast Full-Text Search

```bash
# Search for a topic
qmd search "neural architecture search"

# Search with context (n lines around match)
qmd search --context 3 "attention mechanism"

# Search by tag
qmd search --tag papers

# Search in specific directory
qmd search --path wiki/concepts "transformer"

# List recently modified notes
qmd recent --limit 10

# Show backlinks to a note
qmd backlinks "Attention Mechanism"
```

### 2. ripgrep (rg) - Fallback Search

```bash
# Basic search
rg -i "search term" ~/Knowledge

# Search with file type
rg -i "search term" ~/Knowledge --type md

# Show surrounding context
rg -C 3 -i "search term" ~/Knowledge
```

### 3. File Operations

```bash
# Create new note from template
cat > ~/Knowledge/wiki/papers/new-paper.md << 'EOF'
---
date: 2024-01-15
tags: [paper, ml]
authors: Author Name
venue: Conference Name
year: 2024
status: unread
---

# Paper Title

## Summary

## Key Contributions

## Related
- [[concept-a]]
- [[paper-b]]
EOF

# Read existing note
cat ~/Knowledge/wiki/concepts/transformer.md

# Edit note
edit ~/Knowledge/wiki/concepts/transformer.md

# List notes in a directory
ls ~/Knowledge/wiki/papers/

# Check if note exists
[[ -f ~/Knowledge/wiki/concepts/transformer.md ]] && echo "exists"
```

## Usage Patterns

### Finding Information

**User:** "What do I know about neural architecture search?"

```bash
# Search the vault
qmd search "neural architecture search"

# If results found, read the relevant notes
cat ~/Knowledge/wiki/concepts/neural-architecture-search.md

# Look for related concepts
qmd backlinks "Neural Architecture Search"
```

### Creating New Notes

**User:** "Create a note for the Transformer paper"

```bash
# Create from paper template
cat > ~/Knowledge/wiki/papers/attention-is-all-you-need.md << 'EOF'
---
date: 2024-01-15
tags: [paper, transformers, nlp]
authors: Vaswani et al.
venue: NeurIPS
year: 2017
status: unread
---

# Attention Is All You Need

## Metadata
- **Authors:** Ashish Vaswani, Noam Shazeer, Niki Parmar, Jakob Uszkoreit, Llion Jones, Aidan N. Gomez, Łukasz Kaiser, Illia Polosukhin
- **Venue:** NeurIPS 2017
- **Year:** 2017

## Summary
The Transformer architecture...

## Key Contributions
1. Proposed self-attention mechanism
2. Achieved SOTA on translation tasks
3. More parallelizable than RNNs/LSTMs

## Methods
- Multi-head attention
- Positional encoding
- Feed-forward layers

## Related
- [[RNN]]
- [[LSTM]]
- [[Self-Attention]]
EOF
```

### Answering Questions

**User:** "Explain the attention mechanism based on my notes"

```bash
# Search for relevant notes
qmd search "attention mechanism"
qmd search "self-attention"
qmd search "transformer"

# Read the most relevant notes
cat ~/Knowledge/wiki/concepts/attention-mechanism.md

# Synthesize answer based on notes
```

### Daily Workflow

**User:** "Show me my recent notes and what I was working on"

```bash
# Recently modified notes
qmd recent --limit 20

# Today's daily note (if exists)
DAILY_NOTE="$HOME/Knowledge/Daily/$(date +%Y-%m-%d).md"
[[ -f "$DAILY_NOTE" ]] && cat "$DAILY_NOTE"
```

### Checking for Duplicates

Before creating a new note, check if it already exists:

```bash
# Search by title
qmd search "paper title"

# Search by concept name
qmd search "neural architecture search"

# Check specific path
ls ~/Knowledge/wiki/papers/ | grep -i "attention"
```

## Example Interactions

### Search and Summarize

```
User: "What do I know about diffusion models?"
→ qmd search "diffusion models"
→ Results: wiki/papers/ddpm.md, wiki/concepts/diffusion.md
→ Read both files
→ Provide summary with citations from your notes
```

### Find Connections

```
User: "What papers relate to transformers?"
→ qmd backlinks "Transformer"
→ qmd search --tag transformers
→ List all related papers and concepts
```

### Quick Capture

```
User: "Quick note: idea about using LLMs for knowledge extraction"
→ Create file in Inbox or Daily note
→ Add to ~/Knowledge/Inbox/llm-knowledge-extraction.md
→ Tag for later processing
```

## Best Practices

1. **Start with search** - Always search before creating new notes to avoid duplicates
2. **Use backlinks** - Find related concepts via `qmd backlinks`
3. **Create from templates** - Use consistent structure for papers, concepts, etc.
4. **Link everything** - Add backlinks to connect concepts
5. **Tag appropriately** - Use consistent tags for easy filtering

## Notes

- QMD maintains an index for fast search; run `qmd index` if search seems stale
- The vault is synced via Syncthing; changes propagate to all devices
- Daily notes format: `YYYY-MM-DD.md` in `~/Knowledge/Daily/`
- Templates are in `~/Knowledge/.templates/`
- Focus on file operations (cat, edit, ls) rather than specialized CLI tools
