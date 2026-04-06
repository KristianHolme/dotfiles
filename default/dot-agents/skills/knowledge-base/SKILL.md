---
name: knowledge-base
description: Search and interact with personal knowledge base (Obsidian vault with QMD)
metadata:
  {
    "openclaw":
      {
        "emoji": "🧠",
        "requires":
          {
            "anyBins": ["qmd", "obsidian-cli", "rg"],
            "config": ["knowledge-base.vault_path"],
          },
        "install":
          [
            {
              "id": "qmd",
              "kind": "shell",
              "label": "Install QMD (Query Markdown Database)",
              "command": "curl -sSL https://raw.githubusercontent.com/tobi/qmd/main/install.sh | bash",
              "bins": ["qmd"],
            },
            {
              "id": "obsidian-cli",
              "kind": "shell",
              "label": "Install obsidian-cli",
              "command": "curl -s https://api.github.com/repos/Bip901/obsidian-cli/releases/latest | grep browser_download_url | grep linux-amd64 | head -1 | cut -d'\"' -f4 | xargs curl -sL -o /tmp/obsidian-cli && chmod +x /tmp/obsidian-cli && sudo mv /tmp/obsidian-cli /usr/local/bin/",
              "bins": ["obsidian-cli"],
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
- Create new notes from templates
- Open notes in Obsidian
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

### 2. obsidian-cli - Vault Management

```bash
# Open vault
obsidian-cli open ~/Knowledge

# Create new note from template
obsidian-cli new "wiki/concepts/My New Concept" --template concept

# Open or create daily note
obsidian-cli daily

# Search within vault
obsidian-cli search "topic"
```

### 3. ripgrep (rg) - Fallback Search

```bash
# Basic search
rg -i "search term" ~/Knowledge

# Search with file type
rg -i "search term" ~/Knowledge --type md

# Show surrounding context
rg -C 3 -i "search term" ~/Knowledge
```

## Usage Patterns

### Finding Information

**User:** "What do I know about neural architecture search?"

```bash
# Search the vault
qmd search "neural architecture search"

# If results found, read the relevant notes
read ~/Knowledge/wiki/concepts/neural-architecture-search.md

# Look for related concepts
qmd backlinks "Neural Architecture Search"
```

### Creating New Notes

**User:** "Create a note for the Transformer paper"

```bash
# Create from paper template
obsidian-cli new "wiki/papers/attention-is-all-you-need" --template paper

# Then populate with LLM assistance
edit ~/Knowledge/wiki/papers/attention-is-all-you-need.md
```

### Answering Questions

**User:** "Explain the attention mechanism based on my notes"

```bash
# Search for relevant notes
qmd search "attention mechanism"
qmd search "self-attention"
qmd search "transformer"

# Read the most relevant notes
read ~/Knowledge/wiki/concepts/attention-mechanism.md

# Synthesize answer based on notes
```

### Daily Workflow

**User:** "Show me my recent notes and what I was working on"

```bash
# Recently modified notes
qmd recent --limit 20

# Today's daily note (if exists)
read ~/Knowledge/Daily/$(date +%Y-%m-%d).md
```

## Example Interactions

### Search and Summarize

```
User: Search my knowledge base for "diffusion models"
→ qmd search "diffusion models"
→ Results: wiki/papers/ddpm.md, wiki/concepts/diffusion.md
→ Read both files
→ Provide summary with citations from your notes
```

### Find Connections

```
User: What papers relate to transformers?
→ qmd backlinks "Transformer"
→ qmd search --tag transformers
→ List all related papers and concepts
```

### Quick Capture

```
User: Quick note: idea about using LLMs for knowledge extraction
→ obsidian-cli daily
→ Append to today's daily note
→ Or create inbox item
```

## Best Practices

1. **Start with search** - Always search before creating new notes to avoid duplicates
2. **Use backlinks** - Find related concepts via `qmd backlinks`
3. **Create from templates** - Use obsidian-cli templates for consistent structure
4. **Link everything** - Add backlinks to connect concepts
5. **Tag appropriately** - Use consistent tags for easy filtering

## Notes

- QMD maintains an index for fast search; run `qmd index` if search seems stale
- The vault is synced via Syncthing; changes propagate to all devices
- Daily notes format: `YYYY-MM-DD.md` in `~/Knowledge/Daily/`
- Templates are in `~/Knowledge/.templates/`
