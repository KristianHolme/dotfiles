---
name: asd-ste100
description: "Use when English text must be parsed without a human to resolve ambiguity — tool descriptions, error messages, inter-agent instructions, system prompts, status reports — and misreading has a real cost, or when text reads as dense, hedged, or easy to misparse. Triggers: disambiguate, STE100 rewrite, apply Simplified Technical English, plain-language rewrite, controlled-language rewrite, rewrite so an agent cannot misread this. Not for creative or marketing copy."
version: 0.4.0
---

# Simplified Technical English (ASD-STE100)

Apply the discipline of ASD-STE100 (a controlled English built to stop misreading) for a reader that is an agent or pipeline with no human to resolve ambiguity. The two causes of misreading are words with more than one meaning and sentences with more than one structure. Not for creative or marketing copy, where voice is the point.

## Two Modes

Pick a mode before rewriting. If the user does not say which, infer from the text type and state the choice in one line.

**Strict** — procedures, error messages, tool and function descriptions, inter-agent instructions, safety text. Anywhere a wrong reading has a cost. Apply every rule below, including the hard length caps and one-word-one-meaning discipline.

**STE-flavored** — READMEs, PR descriptions, changelogs, explanatory prose. Apply the structural rules in full and treat the lexical rules as advisory (see Core Rewrite Rules for that split). Keep length caps, active voice, simple tenses, no phrasal verbs, no semicolons, no nominalization, no marketing adjectives. Drop the one-word-one-meaning lockdown: prose needs some range.

## Source and Scope

This skill encodes the rule categories of ASD-STE100 Issue 9, not its ~900-word dictionary. ASD forbids redistribution of the dictionary, so it stays out of this repo. Apply the principle instead: pick the plainest common word and use it the same way every time. When exact approved wording matters (real maintenance documentation), check against the official standard (request form at https://www.asd-ste100.org/STE_downloads.html). Rule summary: `references/writing-rules.md`.

## Core Rewrite Rules

Structural rules (sentence shape) apply from the description alone. Lexical rules depend on the official dictionary, so they are a direction of travel; say so rather than imply dictionary compliance.

### Structural rules — apply these

| Rule | Do | Don't |
|---|---|---|
| Active voice | "The agent deletes the file." | "The file is deleted (by the agent)." — unless the actor is genuinely unknown or irrelevant |
| No phrasal verbs (Rule 9.3) | "Remove the panel." / "Start the job." | "Take off the panel." / "Spin up the job." — a two-word verb has meanings the parts do not predict |
| One instruction per sentence | "Open the file. Read line 3." | "Open the file and read line 3, then check if it matches." |
| Sentence length | ≤20 words for instructions/procedures, ≤25 words for descriptions | Long compound/subordinate-clause sentences |
| No semicolons (Rule 8.1) | Split into separate sentences | Any semicolon at all — STE bans the mark outright, not only as a clause join. (Rule 8.1 permits every other standard punctuation mark. The em dash is *not* banned by STE, though it often signals a sentence that should be split.) |
| Noun clusters | ≤3 words stacked as a noun phrase ("fuel pump valve") | 4+ word noun stacks ("high pressure fuel pump inlet valve assembly") |
| No ellipsis | Keep the subject, verb, and article explicit even if it reads longer | Drop words to save space ("Files not backed up will be lost" → ambiguous which files) |
| Keep modality | "The request **may have** failed." stays "may have" | Promote a hedge to a fact ("The request failed.") or invent a certainty the source did not state |
| Paragraph limits | One topic per paragraph, ≤6 sentences | Multi-topic paragraphs |
| Lists for sequences | Use a numbered or bulleted list for 3+ steps or conditions | Bury a sequence inside one prose sentence |

### Lexical rules — direction of travel only

| Rule | Do | Don't | Why it is weaker here |
|---|---|---|---|
| One word, one meaning | Pick one verb for one action and reuse it every time (e.g. always "check", never mix "check"/"verify"/"confirm" for the same action) | Rotate synonyms for the same idea across a document | Consistency within a document is checkable. Which word is the *approved* one is not, without the dictionary. |
| One part of speech per word | "Apply oil to the valve" (oil = noun) | "Oil the valve" (oil = verb) | Whether "oil" is approved as a noun only is a dictionary fact. Prefer the noun form when both read equally well. Do not claim compliance. |
| Verb, not noun (Rule 3.7) | "Analyze the log." | "Perform an analysis of the log." — a noun form of an action makes the sentence longer and hides who acts | Rule 3.7 says "use an **approved** verb to describe an action." Preferring the verb form is safe to apply anywhere. Knowing which verb is the approved one needs the dictionary. |
| Domain terms | Keep necessary technical nouns/verbs, but define them once if not common English (STE allows a project-specific glossary beyond its base dictionary) | Use jargon without ever defining it | The glossary allowance is real STE, but the base dictionary it extends is absent. |

### Simple tenses — apply with one exception

Allowed: infinitive, imperative, simple present, simple past, simple future, past participle as adjective. Not allowed: present perfect and other compound forms ("we received", not "we have received").
Where the compound form carries information the simple form cannot ("the job has completed" means the output is available now; "may have failed" is a hedge), keep it and flag the departure. Elsewhere, follow the rule.

## Scan Checklist

Scan for these six mechanical habits before you rewrite.

1. **Synonym rotation** — the same thing gets several names in one document ("the user", "the customer", "the client"). The reader cannot tell whether they are one thing or three. Fix: pick one name, use it every time.
2. **Hedge stacking** — helper verbs and qualifiers pile up until the sentence asserts nothing ("it is important to note that this may potentially help to improve"). Fix: state the claim, or delete it.
3. **Nominalization** — an action frozen into a noun ("perform an analysis of", "provides assistance to"). Fix: use the verb ("analyze", "helps").
4. **Marketing adjectives** — words that claim quality instead of showing it: seamless, robust, powerful, cutting-edge, effortless, blazing-fast. Fix: delete, or replace with the measurement that earns the claim.
5. **Run-on sentences** — several ideas joined by semicolons or em dashes. Fix: one idea per sentence.
6. **Soft phrasal verbs** — spin up, reach out, dive into, kick off. Fix: use the single plain verb (start, contact, read, begin).

## Process

1. Pick the mode (Strict or STE-flavored). Say which only when the user asked for the rule table — see Output Format.
2. Read the input once for meaning before rewriting.
3. Walk it sentence by sentence. Flag every rule violation from the Core Rewrite Rules tables and every habit from the Scan Checklist. In STE-flavored mode, flag the lexical rules but do not enforce them. For a mechanical first pass over the structural rules, run `scripts/ste-lint.py` (stdin or file args, `--json` for structured output); it checks semicolons, sentence length, phrasal verbs, nominalization, marketing adjectives, synonym rotation, dangling-conjunction in supported list items, passive voice, and compound tenses, and by design never flags hedges or modality. `--baseline N` tolerates N hard violations (for adopting on existing docs); `--disable rule1,rule2` silences named rules.
4. Rewrite each flagged sentence to fix the violation while preserving the original meaning exactly. If a rewrite would drop necessary precision (a safety condition, a scope qualifier, a number), keep the longer phrasing and flag it instead of silently simplifying.
   - **Check modality before you commit to a rewrite.** Hedges ("may", "could", "sometimes", "is likely to") carry the author's confidence, and confidence is content. A shorter sentence that upgrades a hedge to a fact is not a simplification — it is a different claim. This is the most common way a well-intentioned STE rewrite goes wrong, because hedges are exactly what a length cap tempts you to cut.
   - Never add a fact the source did not state. A rewrite that reads better because it supplies a cause, a frequency, or a mechanism has stopped being a rewrite.
5. Output the rewritten text (see Output Format). Keep the mode choice and the rule analysis internal unless the user asked to see them.
6. If the input already complies, say so — do not force changes onto compliant text.

## Output Format

**Default: the rewritten text, and nothing else.** Most callers want a result they can paste straight into a tool description, an error string, or a prompt. Print the simplified text on its own. Do not add a preamble about this skill, a mode announcement, a violation count, a summary of what changed, a rule table, or a closing offer to explain further.

The one permitted addition: if step 4 kept a longer phrasing on purpose, add a single line after the text, prefixed `Kept as-is:`, naming the phrase and the precision that would have been lost. Omit the line when there is nothing to report.

**On request: the rule table.** When the user asks to see the reasoning — "show the diff", "which rules did it break", "explain the changes", "before/after" — output this table instead:

```markdown
| Rule violated | Original | Simplified |
|---|---|---|
| Present perfect tense | "We have received your request." | "We received your request." |
| Noun cluster (4+ words) | "the agent task queue priority handler" | "the handler that sets task-queue priority" |

Mode: Strict. 7 violations found.
```

Follow the table with a one-line note on anything you deliberately did **not** simplify, and why (usually: simplifying would lose required precision).

## Boundaries

- Preserve every fact, condition, scope qualifier, and safety condition. If shortening would lose one, keep the longer phrasing and flag it.
- Preserve the strength of every hedge. Do not turn "may have failed" into "failed" or "could be caused by X" into "X is the cause". Add no claim the source did not make.
- Do not simplify creative, marketing, or persuasive copy.
- Do not claim certified STE compliance; this is a clarity tool inspired by STE.
- STE fixes form, not substance. If the text has nothing to say, say so instead of polishing it.
- Stop when the sentence is unambiguous, not when it is shortest.
- Suggest a one-line glossary entry for domain terms that must stay.

## Additional Resources

- **`references/writing-rules.md`** — fuller summary of the 9 rule sections and dictionary structure, with citations to the official standard and secondary sources.
- **`examples/before-after.md`** — worked examples, including official STE examples and agent-output examples built for this skill.
- **`scripts/ste-lint.py`** — deterministic linter for the structural rules; `--selftest`, `--json`, `--baseline N`, `--disable` (see Process step 3). Advisory findings never fail the run. It never flags hedges or modality.
