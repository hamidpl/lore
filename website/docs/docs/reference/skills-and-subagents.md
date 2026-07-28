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

## How they fit together

A producer skill orchestrates a run: it records what you asked for, gathers sources (delegating heavy extraction or browsing to a worker subagent) into a receipted source census, writes the documentation, and then calls `lore:doc-validator` to self-verify against the Definition of Done before delivery. The [enforcement hooks](../concepts/enforcement-hooks.md) run independently on top — checking the shape of what was written as files are written, and, at the end of the turn, that the evidence behind it actually exists. Self-verification and deterministic enforcement are deliberately separate: the skill can be wrong about its own work, and the hooks read artifacts it did not author.
