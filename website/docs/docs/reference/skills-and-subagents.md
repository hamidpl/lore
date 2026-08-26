---
sidebar_position: 2
title: Skills & subagents
description: Reference for Lore's authoring skills and supporting worker subagents.
tags: [reference, skills, subagents]
---

# Skills & subagents

## Skills

Skills are the authoring entry points. Three produce documentation from a source; one reviews it.

| Skill | Purpose |
|-------|---------|
| [`lore:figma-to-doc`](../guides/from-figma.md) | Generate docs from Figma design files. |
| [`lore:brief-to-doc`](../guides/from-a-brief.md) | Generate docs from briefs, PRDs, or user stories. |
| [`lore:site-to-doc`](../guides/from-a-live-site.md) | Document a live product by observing it in a browser. |
| [`lore:doc-reviewer`](../guides/review-and-validate.md) | Validate documentation against the Definition of Done. |

## Subagents

Subagents are workers the skills delegate to. They keep the main session's context clean by doing heavy or noisy work in isolation and returning a compact summary.

| Subagent | Role |
|----------|------|
| `lore:doc-validator` | Read-only validator that audits a document against the [Definition of Done](../concepts/definition-of-done.md) and returns a pass/fail report. Producer skills run it before delivery. It treats the source census **adversarially** — as a set of claims to falsify, not a report to read — re-probing sources and testing receipts, because the census was written by the agent whose work it is checking. |
| `lore:figma-extractor` | Heavy Figma extraction — comments, annotations, the frame inventory, and frame images — returned as a distilled summary. |
| `lore:site-explorer` | Heavy live-site exploration — drives the browser, captures screenshots, and records exact UI text — returned as a compact summary. |
| `lore:doc-reviser` | Applies the validator's findings. It receives the report as someone else's work order and may edit **only** the files and sections each finding names, all findings of a round in one batch, one exact occurrence at a time. It has no ability to fetch and cannot create files, so the one kind of defect it cannot introduce is a fabricated source. A fix it cannot apply exactly — because the evidence contradicts it, or because it would need to touch something the finding did not name — comes back unapplied rather than guessed at. |

### Why the fixer is not the writer

Revising a page in the same session that wrote it is where documentation quietly breaks: the reviser exists so the agent that produced a claim is not the one deciding which part of it to change, and so a round's fixes go in **together** rather than one at a time. Findings are routed by kind — text fixes to the reviser, a missing receipt back to source collection (a fixer that cannot fetch must never "resolve" one), and anything needing a product decision to you.

If two consecutive rounds keep finding defects the previous round introduced, the run stops and asks you instead of opening a third.

## How they fit together

A producer skill orchestrates a run: it records what you asked for, gathers sources (delegating heavy extraction or browsing to a worker subagent) into a receipted source census, writes the documentation, and then calls `lore:doc-validator` to self-verify against the Definition of Done before delivery. If that review blocks, the findings go to `lore:doc-reviser` as one batch and exactly the files it edited are re-reviewed. The [enforcement hooks](../concepts/enforcement-hooks.md) run independently on top — checking the shape of what was written as files are written, and, at the end of the turn, that the evidence behind it actually exists. Self-verification and deterministic enforcement are deliberately separate: the skill can be wrong about its own work, and the hooks read artifacts it did not author.
