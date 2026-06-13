---
sidebar_position: 2
title: Quick start
description: From an empty repository to published documentation in four moves — scaffold, generate, review, deploy.
tags: [getting-started, quick-start]
---

# Quick start

Once Lore is [installed and enabled](../getting-started/install.md), you go from an empty repository to published documentation in four moves.

## 1. Scaffold

```text
cd <your-empty-or-existing-project>
/lore:init
```

`/lore:init` asks **three essentials** — product name, documentation language, and whether to install a Docusaurus viewer — then scaffolds the documentation layer (`docs/` and the project's configuration) and, if you chose it, a Docusaurus site.

- **Docusaurus is optional.** Choose **No** for Markdown-only docs and [add a browsable site later](../guides/add-docusaurus.md).
- **Language drives styling.** A right-to-left language (Persian, Arabic, …) gets a [self-hosted Persian font and RTL layout](../concepts/multilingual-rtl.md); left-to-right languages get stock styling.
- **Safe in existing repos.** `/lore:init` only adds the documentation layer and never overwrites your files.

Fill in the rest — site URL, product description, trusted sources, brand color — anytime with [`/lore:config`](../getting-started/configure.md).

## 2. Generate

Run the skill that matches your input:

- [`lore:figma-to-doc`](../guides/from-figma.md) — from design files
- [`lore:brief-to-doc`](../guides/from-a-brief.md) — from briefs, PRDs, or user stories
- [`lore:site-to-doc`](../guides/from-a-live-site.md) — from a live product

## 3. Review

Validate against the [Definition of Done](../concepts/definition-of-done.md) before delivery:

```text
lore:doc-reviewer
```

Producer skills also run a read-only validator automatically at completion, so quality is gated before anything ships.

## 4. Deploy

Ship Markdown-only docs, or build the static site and deploy the output to any host:

```bash
npm run build     # static output in build/ (Docusaurus projects)
```

Deploy the `build/` folder to any static host — Cloudflare Pages, Netlify, Vercel, GitHub Pages, or your own server.
