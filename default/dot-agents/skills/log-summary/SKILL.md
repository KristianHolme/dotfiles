---
name: log-summary
description: Summarize conversations and create Obsidian notes in ~/Documents/AwesomeVault/Agent-summaries. NEVER apply automatically - only activate when manually invoked via /log-summary command, never activate automatically.
---

# Log Summary

Create concise but useful Obsidian notes summarizing conversations. Notes are stored in `~/Documents/AwesomeVault/Agent-summaries/`.

## File Creation

1. Create a new markdown file in `~/Vaults/AwesomeVault/Agent-summaries/`
2. Use kebab-case filename based on the main topic (e.g., `fixing-hyprland-crash.md`)
3. Include YAML frontmatter with metadata
4. Write concise but useful content based on conversation type

## Note Template

```markdown
---
date: YYYY-MM-DD
type: [bug-fix | concept | code | other]
topics: [topic1, topic2]
---

# [Title]

## Summary

[Brief overview of what was discussed/done]

## Details

[Type-specific content - see below]

## Key Takeaways

- Point 1
- Point 2

## References

- Files modified: `path/to/file`
- Links: [name](url)
```

## Content by Type

### OS/System Bug Fix

Describe:

- The problem/symptom
- Root cause (if identified)
- Solution applied
- Commands or config changes made

### Concept Explanation

Include:

- What concept was explained
- Why the user was asking (context)
- User's prior understanding or misconceptions
- Key insights from the explanation

### Code/Project Work

Cover:

- What was built or modified
- Key implementation details
- What remains to do (if anything)
- Knowledge gained about the codebase
- Language features or patterns used
- User preferences revealed

## Guidelines

- Be concise but capture actionable details
- Use Obsidian wiki links `[[like-this]]` for related notes
- Include code snippets if they're short and illustrative
- Note any files that were created or modified
- Capture the "why" not just the "what"
- If the conversation spans multiple topics, create separate notes or use clear sections

## Example

**File:** `fixing-docker-permissions.md`

````markdown
---
date: 2026-02-18
type: bug-fix
topics: [docker, permissions, linux]
---

# Fixing Docker Permission Denied Error

## Summary

User couldn't run docker commands without sudo. Fixed by adding user to docker group.

## Details

**Problem:** Permission denied when running `docker ps`

**Root Cause:** User not in `docker` group

**Solution:**

```bash
sudo usermod -aG docker $USER
newgrp docker
```
````

**Verification:** Ran `docker ps` successfully without sudo

## Key Takeaways

- Docker group membership required for non-root usage
- `newgrp` applies changes without logout/login
- Also works: restart session or reboot

## References

- Files modified: None
- Related: [[docker-cheatsheet]]

```

```
