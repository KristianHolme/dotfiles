---
name: knowledge-base-ingest
description: Process items from inbox/ to raw/ and create wiki notes with links (Karpathy INGEST operation)
metadata:
  {
    "openclaw":
      {
        "emoji": "📥",
        "requires": { "anyBins": ["qmd", "pdftotext"] },
        "install":
          [
            {
              "id": "pdftotext",
              "kind": "pacman",
              "package": "poppler",
              "bins": ["pdftotext"],
              "label": "Install poppler (for pdftotext)",
            },
          ],
      },
  }
---

# Knowledge Base Ingest Skill

Process items from `~/Knowledge/inbox/` → organize into `~/Knowledge/raw/` → create/update wiki notes → update index and log.

This implements the **INGEST** operation from Karpathy's LLM Knowledge Base workflow.

## The INGEST Workflow

When a new source arrives in `inbox/`:

```
User drops source in inbox/
    ↓
[1] LLM reads source, discusses key takeaways with user
    ↓
[2] LLM moves to organized location in raw/ (rename with author-year-title pattern)
    ↓
[3] LLM creates summary page in wiki/sources/ or wiki/papers/
    ↓
[4] LLM updates relevant entity pages in wiki/entities/
    ↓
[5] LLM updates relevant concept pages in wiki/concepts/
    ↓
[6] LLM updates wiki/index.md (adds entry)
    ↓
[7] LLM appends entry to wiki/log.md
```

**A single source might touch 10-15 wiki pages.**

## Key Principle

**Wiki never duplicates content** — it links to raw/ via Obsidian `[[...]]` links:

```markdown
---
title: Paper Title
date: 2024-01-15
tags: [paper, ml]
status: unread
raw: "[[../../raw/papers/author-2024-title.pdf]]"
---

# Paper Title

## Summary
Brief summary...

## Source
See [[../../raw/papers/author-2024-title.pdf|original PDF]]
```

## Tools

### Check Inbox

```bash
# List all unprocessed items in inbox
find ~/Knowledge/inbox -type f -not -name ".DS_Store"

# By type
ls ~/Knowledge/inbox/papers/ 2>/dev/null || echo "No papers"
ls ~/Knowledge/inbox/web/ 2>/dev/null || echo "No web articles"
ls ~/Knowledge/inbox/images/ 2>/dev/null || echo "No images"
```

### Extract Content

```bash
# PDF text extraction
pdftotext -layout "~/Knowledge/inbox/papers/file.pdf" - | head -500

# Markdown files
cat "~/Knowledge/inbox/web/article.md"

# HTML conversion
pandoc -f html -t markdown "file.html" -o "file.md"
```

### Move to Raw (Organize)

```bash
# Rename and move to organized location
# Pattern: author-year-descriptive-name.ext

# Example: Paper
mv "~/Knowledge/inbox/papers/confusing-name.pdf" \
   "~/Knowledge/raw/papers/vaswani-2017-attention-is-all-you-need.pdf"

# Example: Web article
mv "~/Knowledge/inbox/web/article-123.html" \
   "~/Knowledge/raw/web/karpathy-2024-llm-knowledge-base-guide.md"

# Example: Image
mv "~/Knowledge/inbox/images/screenshot.png" \
   "~/Knowledge/raw/images/diagram-architecture-2024.png"
```

### Create Wiki Note (with Link)

```bash
VAULT="$HOME/Knowledge"

# Create wiki note that LINKS to raw (never copies)
cat > "$VAULT/wiki/papers/paper-name.md" << 'EOF'
---
date: 2024-01-15
tags: [paper, ml]
status: unread
raw: "[[../../raw/papers/filename.pdf]]"
---

# Title

## Metadata
- **Authors:**
- **Venue:**
- **Year:**

## Summary
Brief summary...

## Key Contributions
- Point 1
- Point 2

## Related Concepts
- [[concept-a]]
- [[concept-b]]

## Source
[[../../raw/papers/filename.pdf|Original PDF]]
EOF
```

### Update Entity Pages

```bash
# Create or update entity page
cat >> "$VAULT/wiki/entities/vaswani-ashish.md" << 'EOF'
---
date: 2024-01-15
tags: [person, researcher]
---

# Ashish Vaswani

## Role
Researcher, co-author of [[../../papers/attention-is-all-you-need|Attention Is All You Need]]

## Papers
- [[../../papers/attention-is-all-you-need|Attention Is All You Need]] (2017)
EOF
```

### Update Concept Pages

```bash
# Add reference to new source
cat >> "$VAULT/wiki/concepts/self-attention.md" << 'EOF'

## Sources
- Introduced in [[../../papers/attention-is-all-you-need|Attention Is All You Need]]
EOF
```

### Update Index

```bash
# Read current index
cat "$VAULT/wiki/index.md"

# Add entry to appropriate section using edit tool
# Add under "## Papers" section:
# - [[papers/paper-name|Title]] — Description
```

### Update Log

```bash
# Append to log with consistent format
cat >> "$VAULT/wiki/log.md" << 'EOF'

## [$(date +%Y-%m-%d)] ingest | Paper Title
- Source: raw/papers/author-year-title.pdf
- Pages created: papers/paper.md, concepts/concept.md, entities/person.md
- Pages updated: index.md, concepts/related.md
EOF
```

## Usage Patterns

### Process Single Item

**User:** "Process this paper in my inbox"

```bash
# 1. Check what's in inbox/papers
ls ~/Knowledge/inbox/papers/

# 2. Read the PDF
pdftotext "~/Knowledge/inbox/papers/file.pdf" - | head -500

# 3. Extract metadata (LLM reads and extracts)
#    - Title: Attention Is All You Need
#    - Authors: Vaswani et al.
#    - Year: 2017
#    - Venue: NeurIPS

# 4. Move to organized raw/ location
mv "~/Knowledge/inbox/papers/file.pdf" \
   "~/Knowledge/raw/papers/vaswani-2017-attention-is-all-you-need.pdf"

# 5. Create wiki paper summary
cat > "~/Knowledge/wiki/papers/attention-is-all-you-need.md" << 'EOF'
---
date: $(date +%Y-%m-%d)
tags: [paper, transformers, nlp]
authors: Vaswani et al.
venue: NeurIPS
year: 2017
status: unread
raw: "[[../../raw/papers/vaswani-2017-attention-is-all-you-need.pdf]]"
---

# Attention Is All You Need

## Metadata
- **Authors:** Ashish Vaswani, Noam Shazeer, Niki Parmar, Jakob Uszkoreit, Llion Jones, Aidan N. Gomez, Łukasz Kaiser, Illia Polosukhin
- **Venue:** NeurIPS 2017
- **Year:** 2017
- **Source:** [[../../raw/papers/vaswani-2017-attention-is-all-you-need.pdf|PDF]]

## Summary
The Transformer architecture...

## Key Contributions
1. Proposed self-attention mechanism
2. More parallelizable than RNNs

## Related Concepts
- [[Self-Attention]]
- [[Transformer]]
- [[Multi-Head Attention]]

## Source
[[../../raw/papers/vaswani-2017-attention-is-all-you-need.pdf|Original PDF]]
EOF

# 6. Create/update entity pages
# - wiki/entities/vaswani-ashish.md
# - wiki/entities/shazeer-noam.md
# - etc.

# 7. Update concept pages
# Add reference to this paper in:
# - wiki/concepts/self-attention.md
# - wiki/concepts/transformer.md

# 8. Update index.md (add entry under "Papers")

# 9. Append to log.md

# 10. Report completion
```

### Process All Inbox Items

**User:** "Process everything in my inbox"

```bash
# List all items in inbox
find ~/Knowledge/inbox -type f | while read file; do
    # Determine type and process accordingly
    case "$file" in
        *.pdf)
            # Paper processing workflow
            ;;
        *.md)
            # Web article workflow
            ;;
        *.png|*.jpg)
            # Image workflow
            ;;
    esac
done

# Update log.md with summary entry
```

### Check Inbox Status

**User:** "What's in my inbox?"

```bash
# Count items
count=$(find ~/Knowledge/inbox -type f | wc -l)
echo "Inbox: $count items waiting"

# List by type
ls ~/Knowledge/inbox/papers/ 2>/dev/null || echo "No papers"
ls ~/Knowledge/inbox/web/ 2>/dev/null || echo "No web articles"
ls ~/Knowledge/inbox/images/ 2>/dev/null || echo "No images"
```

## File Naming Convention

When moving from inbox to raw, use descriptive names:

```
# Papers
author-year-title-keywords.pdf
vaswani-2017-attention-is-all-you-need.pdf

# Web articles
author-or-site-date-title.md
karpathy-2024-llm-knowledge-base-guide.md

# Books
author-year-book-title.pdf

# Images
date-description.png
2024-01-15-transformer-architecture.png

# Data files
experiment-name.csv
analysis-name.parquet
```

## Link Formats

In wiki notes, link to raw materials:

```markdown
# Relative link from wiki/papers/ to raw/papers/
[[../../raw/papers/vaswani-2017-attention.pdf|Original PDF]]

# In YAML frontmatter
raw: "[[../../raw/papers/vaswani-2017-attention.pdf]]"
```

## Best Practices

1. **Always link, never copy** — Wiki references raw/, doesn't duplicate
2. **Organized filenames** — Use author-year-title pattern in raw/
3. **Check duplicates** — Before moving to raw, check if similar exists
4. **Preserve originals** — Keep raw/ files untouched (reference only)
5. **Summary in wiki** — Put synthesized knowledge in wiki/, full source in raw/
6. **Update index** — Add entry to wiki/index.md after creating page
7. **Log everything** — Append entry to wiki/log.md with consistent format
8. **Touch multiple pages** — One source might update 10-15 wiki pages
9. **Stay involved** — Discuss key takeaways with user during ingest

## Log Entry Format

Append to `wiki/log.md` with this format:

```markdown
## [YYYY-MM-DD] ingest | Source Title
- Source: raw/path/to/file.ext
- Type: paper | book | web | image | audio | data
- Pages created:
  - wiki/papers/title.md
  - wiki/concepts/concept.md
  - wiki/entities/person.md
- Pages updated:
  - wiki/concepts/related.md
  - wiki/topics/overview.md
  - wiki/index.md
```

## Index Entry Format

Add to appropriate section in `wiki/index.md`:

```markdown
## Papers
- [[papers/attention-is-all-you-need|Attention Is All You Need]] — Transformer architecture (Vaswani et al., 2017)
- [[papers/gpt3|Language Models are Few-Shot Learners]] — GPT-3 (Brown et al., 2020)

## Concepts
- [[concepts/self-attention|Self-Attention]] — Mechanism where each position attends to all positions

## Entities
- [[entities/vaswani-ashish|Ashish Vaswani]] — Co-author of Attention Is All You Need
```

## Reporting

After processing, report:

```
📥 INGEST Complete
==================
Source: raw/papers/vaswani-2017-attention.pdf
Type: paper

Pages Created:
✓ wiki/papers/attention-is-all-you-need.md
✓ wiki/concepts/self-attention.md (new)
✓ wiki/entities/vaswani-ashish.md (new)

Pages Updated:
✓ wiki/concepts/transformer.md (added reference)
✓ wiki/index.md (added paper entry)

Log:
✓ wiki/log.md updated

Total wiki pages touched: 6
```

## Error Handling

- **PDF extraction fails** → Log error, leave in inbox, notify user
- **Duplicate detected** → Log, skip, ask if update needed
- **Unknown file type** → Move to inbox/unrecognized/, notify user
- **Metadata extraction uncertain** → Create wiki note, flag for review
- **Source already in raw/** → Check if different version, ask user
