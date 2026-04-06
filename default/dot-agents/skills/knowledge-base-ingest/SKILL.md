---
name: knowledge-base-ingest
description: Process raw materials in ~/raw and compile into structured knowledge base
metadata:
  {
    "openclaw":
      {
        "emoji": "📥",
        "requires":
          {
            "anyBins": ["qmd", "obsidian-cli", "pdftotext", "pandoc"],
            "config": ["knowledge-base.vault_path", "knowledge-base.raw_path"],
          },
        "install":
          [
            {
              "id": "pdftotext",
              "kind": "shell",
              "label": "Install pdftotext (poppler-utils)",
              "command": "sudo apt-get update && sudo apt-get install -y poppler-utils",
              "bins": ["pdftotext"],
            },
            {
              "id": "pandoc",
              "kind": "shell",
              "label": "Install pandoc",
              "command": "sudo apt-get install -y pandoc || brew install pandoc",
              "bins": ["pandoc"],
            },
          ],
      },
  }
---

# Knowledge Base Ingest Skill

Process raw materials from `~/raw/` and compile them into structured notes in your knowledge base.

## Purpose

This skill implements the Karpathy workflow:
1. Scan `~/raw/` for unprocessed files
2. Extract and structure content
3. Create properly formatted notes in `~/Knowledge/wiki/`
4. Add tags, backlinks, and metadata
5. Move processed files to `~/raw/processed/`

## Workflow

```
~/raw/papers/         →  LLM reads, summarizes  →  ~/Knowledge/wiki/papers/
~/raw/web/            →  Structure & clean      →  ~/Knowledge/wiki/topics/
~/raw/images/         →  (Manual processing)    →  ~/Knowledge/Attachments/
~/raw/books/          →  Extract highlights     →  ~/Knowledge/wiki/books/
```

## File Types Supported

- **PDFs** (papers, books) → Extracted via `pdftotext` or read directly
- **Markdown** (web saves) → Restructured and linked
- **HTML** (web pages) → Converted via `pandoc`
- **Images** → Moved to Attachments (manual description recommended)
- **Code repos** → Summary created in wiki/projects/

## Process Steps

For each raw file:

1. **Identify file type** and appropriate processing method
2. **Check for duplicates** using QMD search
3. **Extract content** (PDF text, markdown, etc.)
4. **Summarize with LLM** - Create structured summary
5. **Create note** in appropriate wiki folder
6. **Add metadata** - Tags, date, source, author
7. **Add backlinks** - Link to related concepts
8. **Move to processed/** - Archive original file

## Tools Available

### Text Extraction

```bash
# Extract PDF text
pdftotext -layout "paper.pdf" - | head -100

# Convert HTML to Markdown
pandoc -f html -t markdown "article.html" -o "article.md"

# Read markdown files
cat "notes.md"
```

### Check for Duplicates

```bash
# Search for similar titles/content
qmd search "paper title"
qmd search "author name"
```

### Create Notes

```bash
# Create from template
obsidian-cli new "wiki/papers/paper-name" --template paper

# Or create manually
write ~/Knowledge/wiki/papers/paper-name.md << 'CONTENT'
---
tags: [paper, ml]
---
# Paper Name
## Summary
...
CONTENT
```

### File Operations

```bash
# Move to processed
mv "~/raw/papers/paper.pdf" "~/raw/processed/"

# Or copy and archive
cp "~/raw/papers/paper.pdf" "~/raw/processed/"
rm "~/raw/papers/paper.pdf"
```

## Usage Patterns

### Process All Raw Files

**User:** "Process my raw folder"

```bash
# 1. List all unprocessed files in ~/raw/
find ~/raw -type f -not -path "*/processed/*" -not -name ".DS_Store"

# 2. For each file, determine type and process:
#    - PDFs → Extract, summarize as paper
#    - MD files → Restructure as topic/concept
#    - HTML → Convert to MD, restructure
#    - Images → Move to Attachments

# 3. Create appropriate wiki note
# 4. Move to processed/

# Report summary:
# - X papers processed → wiki/papers/
# - Y web articles → wiki/topics/
# - Z images → Attachments/
```

### Process Specific Directory

**User:** "Process the papers I just added"

```bash
# List PDFs in ~/raw/papers/
ls -la ~/raw/papers/*.pdf

# Process each:
for pdf in ~/raw/papers/*.pdf; do
    # Extract first page for metadata
    pdftotext -f 1 -l 1 "$pdf" - | head -50
    
    # LLM identifies title, authors, key points
    
    # Create wiki note
    obsidian-cli new "wiki/papers/${basename}" --template paper
    
    # Move to processed
    mv "$pdf" ~/raw/processed/
done
```

### Process Single File

**User:** "Add this PDF to my knowledge base"

```bash
# Read PDF content (first N pages)
pdftotext "~/raw/papers/new-paper.pdf" - | head -500 > /tmp/paper.txt
read /tmp/paper.txt

# Check for duplicates
qmd search "extracted title"

# Create note
obsidian-cli new "wiki/papers/new-paper" --template paper
edit ~/Knowledge/wiki/papers/new-paper.md

# Move to processed
mv "~/raw/papers/new-paper.pdf" ~/raw/processed/
```

## Note Templates

### Paper Summary Template

```markdown
---
date: YYYY-MM-DD
tags: [paper, {field}]
authors: {authors}
venue: {venue}
year: {year}
status: unread|reading|read
raw_source: ~/raw/processed/filename.pdf
---

# {title}

## Metadata
- **Authors:** {authors}
- **Venue:** {venue}
- **Year:** {year}

## Summary
{LLM-generated summary}

## Key Contributions
- Point 1
- Point 2
- Point 3

## Methods
{Description of approach}

## Results
{Key findings}

## My Notes
{Personal observations, connections}

## Related
- [[Concept A]]
- [[Paper B]]
- [[Project C]]

---

*Processed: {date}*
*Source: {original filename}*
```

### Web Article Template

```markdown
---
date: YYYY-MM-DD
tags: [article, {topic}]
author: {author}
url: {original_url}
status: unread|read
raw_source: ~/raw/processed/filename.md
---

# {title}

## Source
{url}

## Summary
{LLM-generated summary}

## Key Points
- Point 1
- Point 2

## Related
- [[Topic A]]
- [[Concept B]]

---

*Processed: {date}*
```

### Book Notes Template

```markdown
---
date: YYYY-MM-DD
tags: [book, {genre}]
author: {author}
title: {title}
status: reading|read
raw_source: ~/raw/books/
---

# {title} - {author}

## Summary
{Overview of book}

## Key Insights
- Insight 1
- Insight 2

## Quotes
> "Quote text" — Page X

## Related
- [[Concept A]]
- [[Paper B]]

---

*Processed: {date}*
```

## Duplicate Detection

Before creating a new note, check if it already exists:

```bash
# Search by title
qmd search "paper title"

# Search by author
qmd search "author name"

# Check specific path
ls ~/Knowledge/wiki/papers/ | grep -i "partial-title"
```

If duplicate found:
- Skip creation
- Optionally update existing note with new info
- Log the duplicate

## Backlink Strategy

When processing, identify and create links to:
- **Concepts** mentioned in the content → `[[concepts/...]]`
- **Related papers** → `[[papers/...]]`
- **People** mentioned → `[[people/...]]`
- **Projects** it relates to → `[[projects/...]]`

Use `qmd search` to find existing notes to link to.

## Error Handling

- **Failed PDF extraction** → Log error, skip file, notify user
- **Duplicate detected** → Log, skip creation
- **Missing metadata** → Create note with available info, flag for manual review
- **Unknown file type** → Move to `~/raw/unrecognized/`, notify user

## Batch Processing

For efficiency, process files in batches:
1. Group by type (all PDFs, all MDs)
2. Process similar files together
3. Report summary at end

## Best Practices

1. **Always check for duplicates** before creating new notes
2. **Preserve raw sources** - Keep original in processed/
3. **Add backlinks liberally** - Connect new notes to existing knowledge
4. **Use consistent tags** - Follow existing tag patterns
5. **Include source URLs** - Always reference where content came from
6. **Flag for review** - Mark uncertain extractions for manual check

## Reporting

After processing, provide a summary:

```
📥 Ingest Complete
==================
✓ 3 papers → wiki/papers/
✓ 5 web articles → wiki/topics/
✓ 2 images → Attachments/
⚠ 1 duplicate skipped
⚠ 1 extraction error (logged)
```
