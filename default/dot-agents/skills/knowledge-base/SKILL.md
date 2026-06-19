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

Search and interact with your knowledge base based on Karpathy's LLM Knowledge Base workflow.

## Core Architecture

```
~/Vaults/Wiki/
├── inbox/        # Unprocessed new items (you add here)
├── raw/          # Organized raw materials (immutable sources)
└── wiki/         # LLM-generated knowledge base
    ├── entities/ # People, organizations, tools
    ├── concepts/ # Core concepts and ideas
    ├── papers/   # Paper summaries with links
    ├── topics/   # Topic overviews
    ├── index.md  # CONTENT CATALOG (read this first when querying)
    └── log.md    # CHRONOLOGICAL LOG (ingests, queries, lint)
```

## The Three Operations

### 1. QUERY — Answer Questions

**When user asks a question:**
1. Read `wiki/index.md` to find relevant pages
2. Read the relevant wiki pages
3. Synthesize answer with citations
4. **File valuable answers back into wiki** as new pages

**Key insight:** Read the index first, then drill into specific pages.

### 2. LINT — Health Check

**Periodically check for:**
- Contradictions between pages
- Stale claims superseded by newer sources
- Orphan pages with no inbound links
- Missing pages for important concepts
- Missing cross-references

### 3. INGEST — Add Sources

**(Use knowledge-base-ingest skill for this)**

When new sources arrive in inbox:
1. Move to organized location in raw/
2. Create/update wiki pages
3. Update index.md
4. Append to log.md

## Tools

### QMD — Primary Search

```bash
# Search with JSON output (best for agents - structured, token-efficient)
qmd search "neural architecture search" --json -n 10
qmd query "transformer architecture" --json -n 10 --min-score 0.3

# Get just file paths (most token-efficient for finding files)
qmd search "transformer" --files --min-score 0.4
qmd query "attention mechanism" --files -n 20

# Search specific path
qmd search --path wiki/papers "transformer" --json -n 5

# Search by tag
qmd search --tag papers --json
qmd search --tag concepts --json

# Recent edits
qmd recent --limit 10 --json

# Backlinks (what links to this page)
qmd backlinks "Self-Attention" --json

# Rebuild index
qmd index
```

**Output format recommendations:**
- `--json` - Structured output, easy to parse, includes snippets and scores
- `--files` - Just file paths, most token-efficient when you only need locations
- `--min-score 0.3` - Filter out low-relevance results (saves tokens)
- `-n 10` - Limit results (default is 5, increase for broader queries)

### Reading Wiki Pages

```bash
# Read the index first (when querying)
cat ~/Vaults/Wiki/wiki/index.md

# Read a specific page
cat ~/Vaults/Wiki/wiki/concepts/self-attention.md
cat ~/Vaults/Wiki/wiki/papers/attention-is-all-you-need.md

# Read the log
cat ~/Vaults/Wiki/wiki/log.md | tail -50
```

### File Operations

```bash
# Create new wiki note
cat > ~/Vaults/Wiki/wiki/concepts/new-concept.md << 'EOF'
---
date: $(date +%Y-%m-%d)
tags: [concept, ml]
---

# Concept Name

## Definition

## Related
- [[other-concept]]
- [[../../raw/papers/paper.pdf|Source Paper]]
EOF

# Edit existing note
edit ~/Vaults/Wiki/wiki/concepts/transformer.md

# Check inbox status
find ~/Vaults/Wiki/inbox -type f | wc -l
ls ~/Vaults/Wiki/inbox/*/
```

### ripgrep — Fallback Search

```bash
rg -i "search term" ~/Vaults/Wiki/wiki
rg -i "search term" ~/Vaults/Wiki/raw/papers
rg -C 3 "term" ~/Vaults/Wiki/wiki/papers/
```

## Usage Patterns

### Query: Search for Information

**User:** "What do I know about neural architecture search?"

```bash
# 1. Read the index first
cat ~/Vaults/Wiki/wiki/index.md

# 2. Search with JSON for structured results (includes snippet + score)
qmd search "neural architecture search" --json -n 10

# 3. If found, read the note
cat ~/Vaults/Wiki/wiki/topics/neural-architecture.md

# 4. Check for related papers (use --files for just paths, token-efficient)
qmd search --path wiki/papers "neural architecture" --files
qmd search --tag papers --files

# 5. Find connections (JSON to get context of each link)
qmd backlinks "Neural Architecture Search" --json
```

### Query: Read Raw Material

**User:** "Show me the paper on attention"

```bash
# Find in wiki first (use --files for just paths, most efficient)
qmd search "attention is all you need" --files
cat ~/Vaults/Wiki/wiki/papers/attention-is-all-you-need.md

# Follow link to raw PDF (extract text for LLM)
pdftotext ~/Vaults/Wiki/raw/papers/vaswani-2017-attention.pdf - | head -500
```

### Query: Check Recent Work

**User:** "What was I working on recently?"

```bash
# Read log for recent activity
cat ~/Vaults/Wiki/wiki/log.md | tail -30

# Recent wiki edits via QMD (JSON for structured output)
qmd recent --limit 20 --json

# Today's daily note
DAILY="$HOME/Vaults/Wiki/Daily/$(date +%Y-%m-%d).md"
[[ -f "$DAILY" ]] && cat "$DAILY"

# Inbox status
echo "Inbox: $(find ~/Vaults/Wiki/inbox -type f | wc -l) items waiting"
```

### Create: Add New Note

**User:** "Create a note for the concept of self-attention"

```bash
# 1. Check if exists
qmd search "self-attention"
ls ~/Vaults/Wiki/wiki/concepts/ | grep -i attention

# 2. Create if not exists
cat > ~/Vaults/Wiki/wiki/concepts/self-attention.md << 'EOF'
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
EOF

# 3. Update index.md
# Add entry under "Concepts" section

# 4. Append to log.md
# ## [$(date +%Y-%m-%d)] query | Created self-attention concept page
```

### Lint: Health Check

**User:** "Lint the wiki"

```bash
# 1. List all wiki pages
find ~/Vaults/Wiki/wiki -name "*.md" -type f

# 2. Find orphan pages (no backlinks)
qmd backlinks "Orphan Page Title"  # Check various pages

# 3. Search for contradictions
# Scan pages for conflicting claims

# 4. Check for missing concept pages
# Look for [[Page Name]] links that don't exist

# 5. Update log.md with findings
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

## Updating index.md

When adding new wiki pages:

```markdown
# wiki/index.md structure:
# Knowledge Base Index

## Papers
- [[papers/paper-name|Title]] — One-line description

## Concepts
- [[concepts/concept-name|Name]] — Brief description

## Entities
- [[entities/person-name|Name]] — Role/description

## Topics
- [[topics/topic-name|Name]] — Overview description

## Comparisons
- [[comparisons/x-vs-y|X vs Y]] — Comparison description
```

## Updating log.md

Append entries with consistent prefix:

```markdown
## [2024-01-15] ingest | Paper Title
- Source: raw/papers/author-year-title.pdf
- Pages created/updated: papers/x.md, concepts/y.md

## [2024-01-14] query | User question
- Created: comparisons/x-vs-y.md (valuable answer)
- Sources consulted: papers/a.md, concepts/b.md

## [2024-01-13] lint | Health check
- Issues found: 2 orphans, 1 contradiction
- Actions: linked orphans, flagged contradiction
```

## Best Practices

1. **Read index first** — When querying, start with wiki/index.md
2. **File good answers** — Valuable answers become new wiki pages
3. **Use links** — Reference raw/ materials, don't duplicate
4. **Consistent tags** — Use tag patterns across notes
5. **Check backlinks** — Use `qmd backlinks` to find connections
6. **Log everything** — Append to wiki/log.md for tracking
7. **Check inbox** — Remind user if inbox is accumulating

## Response Templates

### After QUERY:
```
📋 QUERY Answered
=================
Question: "..."

Sources Consulted:
- wiki/papers/paper.md
- wiki/concepts/concept.md
- raw/papers/source.pdf

Answer:
[Answer with citations to sources]

Filing:
✓ Created wiki/comparisons/comparison.md (valuable answer)
✓ Updated wiki/index.md
✓ Updated wiki/log.md
```

### After LINT:
```
🧹 LINT Complete
================
Issues Found: N

⚠️ Orphan: wiki/concepts/x.md (no inbound links)
⚠️ Contradiction: X in papers/a.md vs not-X in papers/b.md
⚠️ Missing: papers/c.md references "concept" but no page exists

Recommendations:
[Actions to take]

Log:
✓ wiki/log.md updated
```
