# Skill body patterns

Read when choosing how to shape a skill body: output templates, examples, multi-step workflows, branching, validation loops, or bundled scripts.

## Template

Give the output format as a template when the format is fixed:

````markdown
## Report structure

```markdown
# [Analysis Title]
## Executive summary
[One-paragraph overview]
## Recommendations
1. Specific actionable recommendation
```
````

## Examples

When output quality depends on seeing the target, give input/output pairs (two or three, not more):

````markdown
**Example 1:**
Input: Added user authentication with JWT tokens
Output:
```
feat(auth): implement JWT-based authentication
```
````

## Workflow with checklist

For multi-step work, give a checklist the agent copies and ticks, then one short block per step with the command to run.

```markdown
Task Progress:
- [ ] Step 1: Analyze the form
- [ ] Step 2: Create field mapping
- [ ] Step 3: Validate mapping
```

## Conditional workflow

Name the decision, then point each branch at its own section:

```markdown
**Creating new content?** → "Creation workflow" below
**Editing existing content?** → "Editing workflow" below
```

## Feedback loop

For quality-critical work, end with a check: make edits, run the validator, fix and rerun on failure, proceed only when it passes.

## Utility scripts

A shipped script is more reliable than generated code and keeps code out of context. State whether the agent should run it or read it (usually run), and give the command plus what it returns:

```markdown
**validate.py**: `python scripts/validate.py fields.json` returns "OK" or lists conflicts
```

Scripts handle errors themselves rather than punting to the agent, and document required packages.

## Time-sensitive information

Do not write "before August 2025, use the old API". State the current method, and put legacy methods in a collapsed `<details>` "Old patterns" section.
