---
name: knowledge-base-ingest
description: Process items from inbox/ to raw/ and create wiki notes with links
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

Process items from `~/Knowledge/inbox/` → organize into `~/Knowledge/raw/` → create wiki notes linking to raw materials.

## Purpose (Karpathy Workflow)

1. **Scan inbox/** for unprocessed items
2. **Move** item to organized location in raw/ (rename, categorize)
3. **Create** wiki note with **link** to raw material (not copy)
4. **Empty** inbox for this item

## Key Principle

**Wiki never duplicates content** — it links to raw/ via Obsidian `[[...]]` links:

```markdown
---
title: Paper Title
raw: "[[../../raw/papers/author-2024-title.pdf]]"
---

# Paper Title

## Summary
Brief summary...

## Full Source
See [[../../raw/papers/author-2024-title.pdf|original PDF]]
```

## Workflow

### User
```
# User drops new paper in inbox
~/Knowledge/inbox/papers/random-download.pdf
```

### Agent
```
# 1. Read PDF
pdftotext "~/Knowledge/inbox/papers/random-download.pdf" - | head -500

# 2. Identify metadata (title, authors, year, venue)

# 3. Create organized filename
#    FROM: random-download.pdf
#    TO:   author-2024-paper-title.pdf

# 4. Move to raw/
mv "~/Knowledge/inbox/papers/random-download.pdf" \
   "~/Knowledge/raw/papers/author-2024-paper-title.pdf"

# 5. Create wiki note with LINK to raw
#    (wiki contains summary, raw contains full PDF)
cat > "~/Knowledge/wiki/papers/paper-title.md" << 'EOF'
---
date: 2024-01-15
tags: [paper, ml]
status: unread
raw: "[[../../raw/papers/author-2024-paper-title.pdf]]"
---

# Paper Title

## Metadata
- **Authors:** Author Name
- **Venue:** Venue Name
- **Year:** 2024
- **Source:** [[../../raw/papers/author-2024-paper-title.pdf|PDF]]

## Summary
LLM-generated summary...

## Key Contributions
- Point 1
- Point 2

## Related
- [[concept-a]]
- [[paper-b]]
EOF

# 6. Result: inbox empty for this item, raw has organized PDF, wiki has summary with link
```

## Tools

### Check Inbox

```bash
# List all unprocessed items in inbox
ls -la ~/Knowledge/inbox/*/
find ~/Knowledge/inbox -type f -not -name ".DS_Store"

# Check specific folder
ls ~/Knowledge/inbox/papers/
ls ~/Knowledge/inbox/web/
```

### Extract Content

```bash
# PDF text extraction
pdftotext -layout "~/Knowledge/inbox/papers/file.pdf" - | head -500

# Markdown files
cat "~/Knowledge/inbox/web/article.md"

# HTML conversion (if needed)
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
   "~/Knowledge/raw/web/karpathy-llm-knowledge-base-guide.md"

# Example: Image
mv "~/Knowledge/inbox/images/screenshot.png" \
   "~/Knowledge/raw/images/diagram-architecture-2024.png"
```

### Create Wiki Note (with Link)

```bash
# Create wiki note that LINKS to raw (never copies)
VAULT="$HOME/Knowledge"

cat > "$VAULT/wiki/papers/paper-name.md" << 'EOF'
---
date: 2024-01-15
tags: [paper, ml]
status: unread
raw: "[[../../raw/papers/filename.pdf]]"
---

# Title

## Summary
Brief summary...

## Source
[[../../raw/papers/filename.pdf|Original PDF]]

## Related
- [[concept-a]]
EOF
```

### Check for Duplicates

```bash
# Before moving to raw, check if similar file exists
ls ~/Knowledge/raw/papers/ | grep -i "author-name"
qmd search "paper title"
```

## Usage Patterns

### Process Single Item

**User:** "Process this paper in my inbox"

```bash
# 1. Check what's in inbox/papers
ls ~/Knowledge/inbox/papers/

# 2. Read the PDF
pdftotext "~/Knowledge/inbox/papers/file.pdf" - | head -500

# 3. Identify metadata (LLM reads and extracts)
#    - Title: Attention Is All You Need
#    - Authors: Vaswani et al.
#    - Year: 2017
#    - Venue: NeurIPS

# 4. Move to organized raw/ location
mv "~/Knowledge/inbox/papers/file.pdf" \
   "~/Knowledge/raw/papers/vaswani-2017-attention-is-all-you-need.pdf"

# 5. Create wiki note with LINK
cat > "~/Knowledge/wiki/papers/attention-is-all-you-need.md" << 'EOF'
---
date: 2024-01-15
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

## Methods
- Multi-head attention
- Positional encoding

## Related
- [[RNN]]
- [[LSTM]]
- [[Self-Attention]]
- [[../../raw/papers/vaswani-2017-attention-is-all-you-need.pdf|Original PDF]]
EOF

# 6. Done - inbox empty, raw organized, wiki has summary with link
```

### Process All Inbox Items

**User:** "Process everything in my inbox"

```bash
# List all items in inbox
find ~/Knowledge/inbox -type f | while read file; do
    # Determine type
    case "$file" in
        *.pdf)
            # Paper processing
            pdftotext "$file" - | head -500
            # Extract metadata
            # Move to raw/papers/
            # Create wiki/papers/note.md with link
            ;;
        *.md)
            # Web article processing
            cat "$file"
            # Move to raw/web/
            # Create wiki/topics/note.md with link
            ;;
        *.png|*.jpg)
            # Image processing
            # Move to raw/images/
            # Create description in wiki if needed
            ;;
    esac
done
```

### Check Inbox Status

**User:** "What's in my inbox?"

```bash
# Count items
find ~/Knowledge/inbox -type f | wc -l

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

# Code repos
date-project-name/
2024-01-15-transformer-impl/

# Images
date-description.png
2024-01-15-transformer-architecture.png
```

## Link Formats

In wiki notes, link to raw materials:

```markdown
# Relative link from wiki/papers/ to raw/papers/
[[../../raw/papers/vaswani-2017-attention.pdf|Original PDF]]

# Relative link from wiki/concepts/ to raw/papers/
[[../../raw/papers/vaswani-2017-attention.pdf|Vaswani et al. 2017]]

# In YAML frontmatter
raw: "[[../../raw/papers/vaswani-2017-attention.pdf]]"
```

## Best Practices

1. **Always link, never copy** — Wiki references raw/, doesn't duplicate
2. **Organized filenames** — Use author-year-title pattern in raw/
3. **Check duplicates** — Before moving to raw, check if similar exists
4. **Preserve originals** — Keep raw/ files untouched (reference only)
5. **Summary in wiki** — Put synthesized knowledge in wiki/, full source in raw/
6. **Clear inbox** — After processing, item should be out of inbox/

## Reporting

After processing:

```
📥 Ingest Complete
==================
Processed from inbox/:
✓ 3 papers → raw/papers/ + wiki/papers/ (with links)
✓ 5 web articles → raw/web/ + wiki/topics/ (with links)
✓ 2 images → raw/images/
⚠ 1 duplicate skipped
⚠ 1 item needs manual review

Current inbox status:
📁 inbox/papers/ - 0 items
📁 inbox/web/ - 0 items
📁 inbox/images/ - 1 item (needs manual processing)
```

## Error Handling

- **PDF extraction fails** → Log error, leave in inbox, notify user
- **Duplicate detected** → Log, skip, ask if update needed
- **Unknown file type** → Move to inbox/unrecognized/, notify user
- **Metadata extraction uncertain** → Create wiki note, flag for review
