---
name: scientific-paper-feedback
description: Give detailed feedback on scientific papers against established writing guidelines. Use when reviewing a paper, manuscript, or LaTeX draft, or when the user asks for paper feedback, writing review, or scientific writing critique.
---

# Scientific Paper Feedback

Provide **detailed** feedback on scientific papers by checking the manuscript against two guideline sources. Fetch and read both before reviewing.

## Guideline Sources (fetch first)

1. **GitHub guidelines (LaTeX, style, structure, content)**  
   Fetch the **raw markdown** to save tokens:
   - URL: `https://raw.githubusercontent.com/jerabaul29/guidelines_writing_papers/main/README.md`

2. **Stanford technical writing tips (structure, mechanics, grammar)**  
   Fetch the page content (e.g. with a web fetch tool):
   - URL: `https://cs.stanford.edu/people/widom/paper-writing.html`

Use these as the authority for what counts as a violation. Cite guideline identifiers where they exist (e.g. F:S2, F:L3) or the section/rule from Stanford.

## Feedback Structure

Unless the user asks for a specific feedback format, split feedback into two sections:

### 1. Technical

- Typos and spelling
- LaTeX issues (citation style `\citep` vs `\citet`, punctuation around equations, consistency, indentation)
- Formatting (figures/tables placement, captions, references in text)
- Mechanics (spellcheck, figure fonts, etc.)
- punctuation rules, including correct usage of "i.e.," and "e.g.,"
- consistency in placement of footnotes

### 2. Writing

- Style (tense, passive voice, sentence length, hyperboles, terminology consistency)
- Structure (abstract, introduction, story, contributions by page 3)
- Clarity (ambiguity, "which" vs "that", nonreferential "this/that", etc.)
- Any other content/style rules from the two guideline sources

## Reporting Each Violation

For **every** place a guideline is violated, report:

| Field          | Requirement                                                                                     |
| -------------- | ----------------------------------------------------------------------------------------------- |
| **Location**   | Line number(s) preferred; otherwise section + short position description                        |
| **Excerpt**    | Short verbatim quote of the offending text (1–3 sentences max)                                  |
| **Guideline**  | Which rule is violated (e.g. "F:S2 – short sentences", "Stanford: avoid nonreferential 'this'") |
| **Suggestion** | Concrete correction or rewrite                                                                  |

Example:

```markdown
- **Location:** Line 42
- **Excerpt:** "Our method is very effective and we have shown that it can be applied in a variety of different scenarios."
- **Guideline:** F:S0 (avoid strong/vague adjectives like "very"); F:S2 (one idea per sentence).
- **Suggestion:** "Our method is effective in the settings we tested. We show that it applies to scenarios X and Y."
```

## Workflow

1. **Fetch** both guideline URLs and read them.
2. **Obtain** the paper text (full .tex, exported text, or provided excerpt). If only PDF or partial text is available, use what you have and state the limitation.
3. **Review** section by section; note every violation with location, excerpt, guideline, and suggestion.
4. **Output** the two-part report (Technical, then Writing), each with violations in order of appearance in the paper.
5. Optionally end with a **short summary** (counts per category, most critical fixes).

## Reference

- Detailed violation format and guideline IDs: [reference.md](reference.md)
