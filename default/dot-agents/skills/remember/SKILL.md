---
name: remember
description: >-
  Reflect on agent behavior the user disliked or wants done differently, find
  its root cause in the guidance the agent was given, and propose a durable fix
  (edit a skill, create a skill, update AGENTS.md or docs). For passive capture
  of corrections, see agent-self-improvement.
disable-model-invocation: true
argument-hint: "What should the agent do differently?"
---

# Remember

The user invokes this when the agent did something unnecessary or wrong, or
when they want something done in a particular way from now on. Goal: change the
guidance so the behavior does not recur, at the root cause and in the right
place.

The text after `/remember` is the user's complaint or preference. If it is
empty, use the most recent behavior the user objected to. If it is still
unclear, ask one question.

## Steps

1. **Restate** the behavior and the desired behavior in one or two lines.
2. **Find the cause.** Do not guess. Look at what shaped the behavior:
   - Skills that were loaded or should have applied: read them.
   - `AGENTS.md` / `CLAUDE.md` in the project and in `~`, plus docs they link.
   - Memory files, READMEs, and code comments the agent relied on.
   - The agent's own earlier reasoning in the session: a premature assumption,
     a default carried over from another stack, a rule applied too broadly.
3. **Classify the cause:**
   - Missing guidance: nothing covers this.
   - Outdated guidance: a doc, skill, or preference no longer matches reality.
   - Conflicting guidance: two sources disagree.
   - Over-broad or over-eager guidance: a rule triggers where it should not.
   - Agent assumption: no guidance is wrong; the agent assumed without checking.
4. **Choose where the fix goes** (most specific place that will be read when it
   matters):

   | Cause / knowledge | Target |
   | --- | --- |
   | Existing skill is wrong, outdated, or too broad | Edit that skill |
   | Stack or workflow rule reused across repos, no skill fits | Extend the closest skill; create a new skill only if it is a distinct workflow |
   | Repo-specific convention | Project `AGENTS.md` |
   | Stale factual doc (README, docs/) | Fix that doc |
   | Personal preference for all sessions | User-level `AGENTS.md` or memory |
   | Conflict between sources | Fix the wrong one; delete the duplicate |

   In the dotfiles repo, skills live in `default/dot-agents/skills/`; read that
   repo's `AGENTS.md` first for sync quirks.
5. **Propose the edit.** Show the cause in one line, the target file, and the
   exact change as a diff or the new text. Prefer removing or rewording a bad
   rule over stacking a new rule on top of it. Keep additions short: one sharp
   rule beats a paragraph. State the rule as what to do, not as a history of
   the incident (see `code-comments`).
6. **Ask before writing.** Apply only after the user agrees. If several
   independent fixes apply, list them so the user can accept each one.
7. After writing, say which files changed. Do not commit unless asked.

## Rules

- Find evidence for the cause. If you cannot find one, say so and treat it as
  an agent assumption; do not invent a cause.
- Do not turn a one-off request into a permanent rule. If it might be
  one-off, ask whether it should apply generally.
- Do not paste long postmortems into skills.
- Do not add a new skill for one line when an existing skill fits.
- Never edit files under `/usr/share/omarchy` or other read-only system paths.
