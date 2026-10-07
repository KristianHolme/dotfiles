---
name: retro
description: >-
  Review a coding session for changes to the agent's environment: navigation,
  automated checks, review rules, tool use, and steering-file no-ops. A single
  disliked behavior is remember. A correction during the session is
  agent-self-improvement.
disable-model-invocation: true
argument-hint: "Which session? (default: this one)"
---

# Retro

The user wants a retrospective. Suggest changes to the agent's environment so later runs go better. Present candidates. Edit files only after the user agrees.

A single disliked behavior, or a preference for how to work from now on, is `remember`. That skill finds the guidance and proposes the edit. A correction during the session is `agent-self-improvement`. This skill looks across a whole session for environment gaps those two do not cover. A note of what happened, with no environment change, is `log-summary`.

## Steps

1. Read `writing-for-agents` before proposing a skill, `AGENTS.md`, or `CLAUDE.md` edit.
2. Read the session the user names. If they name none, use the current one. On this machine, transcripts live in:
   - Cursor: `~/.cursor/projects/<project>/agent-transcripts/`
   - Codex: `~/.codex/sessions/`
   - Claude: `~/.claude/projects/` and `~/.claude/transcripts/`
   Done when the session's tool calls, mistakes, and the steering files in play have been read.
3. Collect candidates in the categories below. Skip a category with no evidence in the session.
4. Present the candidates in order of severity. For each one, give the evidence, the category, the target file or check, and the exact change. A guidance edit uses `remember`'s placement rules. Stop there. Apply only what the user accepts.

## Categories

- **Navigation.** The agent took a long time to find a file or a hidden dependency. Add a navigation pointer in the repo `AGENTS.md`, or in a doc that file already points at.
- **Automated checks.** The agent made a mistake a linter, type check, test, or filesystem check could have caught. Or the repo has no guardrail: no pre-commit hook and no CI job that runs its lint, typecheck, or test command. Read the repo's own check command first. A check that already exists but is unwired or broken is the finding.
- **Coding standards.** The review pass missed a mistake. Classify it first. A mechanical violation (a fixed syntactic pattern, a banned API, an import shape, a file-location rule) gets a deterministic check: a linter rule, a pre-commit hook, or a CI job, whichever the repo already makes cheapest. A judgement call (cross-file consistency, matching surrounding style) goes in an existing review skill (`review-api`, `review-design`, `code-comments`, or the closest one). Build the check when a check can exist.
- **Steering bulk.** `AGENTS.md` or `CLAUDE.md` (repo or `~/`) is large, and a rule there belongs in a check or a review skill. Move it.
- **Tool economy.** The agent repeated an expensive tool call, or a CLI or MCP spends too many tokens. Name the call and the cheaper path.
- **No-ops.** A line in a steering file does not change behavior versus the model's default. Delete the line. See `writing-for-agents`.
- **Information access.** A fact the agent needed was not available (dev-server logs, read-only access to a service). Name the access to add.

## Reference

Implementation carries the context pressure: exploration, writing, debugging. Review sees a diff. Put judgement rules on the review skill, not in the always-loaded `AGENTS.md`. Keep `AGENTS.md` to navigation pointers and facts the agent cannot look up.

Skills live in `~/dotfiles/default/dot-agents/skills/`. There is no `CODING_STANDARDS.md`. Do not create one to hold a rule a skill or a check can hold.
