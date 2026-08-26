---
slug: /
sidebar_position: 1
title: Introduction
description: What Lore is — a reusable, product-agnostic documentation factory packaged as a Claude Code plugin.
tags: [introduction, overview]
---

# Lore

**Lore is a reusable, product-agnostic documentation factory packaged as a [Claude Code](https://code.claude.com/docs/en/plugins) plugin.** Install it in any documentation repository to get the same authoring skills, review subagents, and blocking-rule enforcement hooks — maintained once, consumed everywhere.

:::info Stable
Lore follows [semantic versioning](https://semver.org): breaking changes to commands, templates, or conventions land only in a major release. See [Versioning](./versioning.md) to pin a fixed tag.
:::

## The problem it solves

Screens change, briefs drift, and the live product moves on — while the docs quietly fall behind. Most teams reinvent their own writing rules, review steps, and folder conventions from scratch, in every repo.

Lore packages that whole methodology once. Install the plugin and every repository inherits the same skills, the same Definition of Done, and the same guardrails. Fix something in the plugin and every repo picks up the change with a single update.

## Three ways to author

Start from whatever input you already have. Each path is a guided skill that reads the source, asks the right questions, and writes structured documentation.

| Source | Skill | Use it when |
|--------|-------|-------------|
| Figma designs | [`lore:figma-to-doc`](./guides/from-figma.md) | You have design files, mockups, or annotations |
| Briefs / PRDs | [`lore:brief-to-doc`](./guides/from-a-brief.md) | You have written requirements or user stories |
| A live product | [`lore:site-to-doc`](./guides/from-a-live-site.md) | You want to document how the product actually behaves |

Validate the result against the [Definition of Done](./concepts/definition-of-done.md) with [`lore:doc-reviewer`](./guides/review-and-validate.md) before delivery.

## How it fits together

Lore carries only the **product-agnostic methodology**. Everything product-specific — trusted sources, user roles, document structure, language — lives in the consuming repository's own configuration. That [division of responsibility](./concepts/division-of-responsibility.md) is what lets one set of skills serve every product.

An optional [Docusaurus viewer](./guides/add-docusaurus.md) turns the Markdown into a browsable, [multilingual and RTL-ready](./concepts/multilingual-rtl.md) site — the same engine that builds the documentation you are reading now.

## Where to next

- **New here?** Start with [Install](./getting-started/install.md), then the [Quick start](./getting-started/quick-start.md).
- **Want the concepts?** Read [Division of responsibility](./concepts/division-of-responsibility.md) and the [Definition of Done](./concepts/definition-of-done.md).
- **Looking something up?** Jump to the [Reference](./reference/commands.md).
