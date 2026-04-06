---
name: knowledge-base
description: Search and interact with personal knowledge base (inbox/raw/wiki structure)
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

Search and interact with your knowledge base (inbox/raw/wiki structure).

## Structure

```
~/Knowledge/
├── inbox/     # Unprocessed new items (you add here)
├── raw/       # Organized raw materials (agent moves here from inbox)
└── wiki/      # Compiled knowledge with links to raw/
```

## Purpose

- **Search** wiki and raw materials via QMD
- **Read** wiki notes and raw materials
- **Create** new wiki notes with links to raw/
- **Check** inbox status
- **Answer** questions based on your knowledge

## Tools

### 1. QMD - Search

```bash
# Search wiki
qmd search "neural architecture search"
qmd search --path wiki "transformer"

# Search raw materials
qmd search --path raw/papers "attention"
qmd search --path raw "author name"

# Search by tag
qmd search --tag papers
qmd search --tag concepts

# Recently modified
qmd recent --limit 10

# Backlinks
qmd backlinks "Attention Mechanism"
```

### 2. File Operations

```bash
# Read wiki note
cat ~/Knowledge/wiki/papers/attention-is-all-you-need.md

# Read raw material (PDF text)
pdftotext ~/Knowledge/raw/papers/vaswani-2017-attention.pdf - | head -100

# Create new wiki note
cat > ~/Knowledge/wiki/concepts/new-concept.md << 'EOF'
---
date: 2024-01-15
tags: [concept, ml]
---

# Concept Name

## Definition

## Explanation

## Related
- [[../../raw/papers/vaswani-2017-attention.pdf|Source Paper]]
EOF

# Edit existing note
edit ~/Knowledge/wiki/concepts/transformer.md

# Check inbox
ls ~/Knowledge/inbox/papers/
ls ~/Knowledge/inbox/web/
find ~/Knowledge/inbox -type f | wc -l

# List wiki directory
ls ~/Knowledge/wiki/papers/
ls ~/Knowledge/wiki/concepts/
```

### 3. ripgrep - Fallback Search

```bash
rg -i "search term" ~/Knowledge/wiki
rg -i "search term" ~/Knowledge/raw/papers
rg -C 3 "term" ~/Knowledge/wiki/papers/
```

## Usage Patterns

### Search for Information

**User:** "What do I know about neural architecture search?"

```bash
# Search wiki
qmd search "neural architecture search"

# If found, read the note
cat ~/Knowledge/wiki/concepts/neural-architecture-search.md

# Also check for related papers
qmd search --path raw/papers "neural architecture"

# Find connections
qmd backlinks "Neural Architecture Search"
```

### Read Raw Material

**User:** "Show me the paper on attention"

```bash
# Find in wiki first
qmd search "attention is all you need"
cat ~/Knowledge/wiki/papers/attention-is-all-you-need.md

# Follow link to raw PDF
cat ~/Knowledge/raw/papers/vaswani-2017-attention.pdf
# (or extract text)
pdftotext ~/Knowledge/raw/papers/vaswani-2017-attention.pdf - | head -500
```

### Check Inbox

**User:** "What's in my inbox?"

```bash
# List all items
find ~/Knowledge/inbox -type f

# By type
ls ~/Knowledge/inbox/papers/ 2>/dev/null || echo "No papers"
ls ~/Knowledge/inbox/web/ 2>/dev/null || echo "No web"
ls ~/Knowledge/inbox/images/ 2>/dev/null || echo "No images"

# Count
echo "Total in inbox: $(find ~/Knowledge/inbox -type f | wc -l)"
```

### Create Note

**User:** "Create a note for the concept of self-attention"

```bash
# Check if exists
qmd search "self-attention"
ls ~/Knowledge/wiki/concepts/ | grep -i attention

# Create if not exists
cat > ~/Knowledge/wiki/concepts/self-attention.md << 'EOF'
---
date: $(date +%Y-%m-%d)
tags: [concept, transformers, attention]
---

# Self-Attention

## Definition
A mechanism where each position in a sequence attends to all positions...

## Mathematical Formulation
$Attention(Q, K, V) = softmax(\frac{QK^T}{\sqrt{d_k}})V$

## In Context
Introduced in [[../../raw/papers/vaswani-2017-attention.pdf|Attention Is All You Need]].

## Related
- [[Multi-Head Attention]]
- [[Transformer]]
- [[../../raw/papers/vaswani-2017-attention.pdf|Original Paper]]
EOF
```

### Daily Check

**User:** "What was I working on recently?"

```bash
# Recent wiki edits
qmd recent --limit 20

# Today's daily note
DAILY="$HOME/Knowledge/Daily/$(date +%Y-%m-%d).md"
[[ -f "$DAILY" ]] && cat "$DAILY"

# Inbox status
echo "Inbox: $(find ~/Knowledge/inbox -type f | wc -l) items waiting"
```

## Linking to Raw Materials

Always link to raw/ rather than duplicating:

```markdown
# In wiki/papers/paper-summary.md:
---
title: Paper Title
raw: "[[../../raw/papers/author-2024-title.pdf]]"
---

Summary here...

Full paper: [[../../raw/papers/author-2024-title.pdf|click to open]]
```

## Best Practices

1. **Search first** — Before creating, check if note exists
2. **Use links** — Reference raw/ materials, don't duplicate
3. **Consistent tags** — Use tag patterns across notes
4. **Backlinks** — Add `qmd backlinks` to find connections
5. **Check inbox** — Remind user if inbox is accumulating
