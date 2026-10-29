---
name: create-skill
description: Guides users through creating effective Agent Skills for OpenCode. Use when you want to create, write, or author a new skill, or asks about skill structure, best practices, or SKILL.md format.
---

# Creating Skills

Skills live in `~/dotfiles/default/dot-agents/skills/<skill-name>/` (part of the dotfiles repo, synced to every project). Also read `writing-for-agents` for how to write the content, and run `node skill-diet/scripts/eval.mjs check <skill-dir>` (from the skills directory) for size and link checks.

## Gather requirements

Ask the user, or infer from the conversation if it already shows a workflow worth capturing:

1. Purpose and scope: which task or workflow.
2. Trigger scenarios: when the agent should apply it.
3. Domain knowledge the agent would not already have.
4. Required output formats or templates.
5. Existing patterns or conventions to follow.

## Structure

```
skill-name/
├── SKILL.md        # required
├── references/     # optional: detail only some tasks need
└── scripts/        # optional: run, not read
```

`SKILL.md` has YAML frontmatter plus a markdown body.

| Field | Rules |
|---|---|
| `name` | Max 64 chars, lowercase letters/numbers/hyphens. Specific: `processing-pdfs`, not `helper` or `utils`. |
| `description` | Max 1024 chars, non-empty. |

## Description

The description is injected into the system prompt and decides when the skill fires.

- Third person ("Processes Excel files"), never "I can" or "You can".
- State WHAT it does and WHEN to use it, with the trigger terms a user would say.
- Example: "Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction."

## Principles

- **Concise.** The context window is shared. Assume the agent is smart; add only what it does not already know. Challenge each paragraph's token cost.
- **Progressive disclosure.** Essentials in `SKILL.md` (under 500 lines); detail in files the agent reads only when needed, linked directly from `SKILL.md` (one level deep, since nested links may be partially read) with a note on when to read each.
- **Degrees of freedom.** Match specificity to fragility: text guidance when many approaches work, templates when a pattern is preferred, exact scripts for fragile operations.
- **One default.** Give one recommended option with an escape hatch, not a menu of libraries.
- **One term per concept.** Do not mix "endpoint"/"URL"/"route".
- **Forward-slash paths** (`scripts/helper.py`).

Body patterns (templates, examples, checklists, branching, feedback loops, scripts, legacy info): [references/patterns.md](references/patterns.md), read when shaping the body.

## Workflow

1. Discovery: purpose, trigger scenarios, constraints, existing examples.
2. Design: name, third-person description, section outline, whether references or scripts are needed.
3. Implement: create the directory, write `SKILL.md`, then references and scripts.
4. Verify: `SKILL.md` under 500 lines; description specific with triggers; consistent terminology; links one level deep; run the check command above.

## Script checklist

Scripts solve problems rather than punt, document required packages, and handle errors with helpful messages.
