---
sidebar_position: 3
title: Configure a project
description: Use /lore:config to fill in or edit project settings — site URL, product description, trusted sources, doc template, brand color, and the init answers.
tags: [getting-started, configuration]
---

# Configure a project

`/lore:init` fills only the essentials. Everything else is set — and re-set — with **`/lore:config`**, which you can run anytime. Every question is optional and skippable, and the command is idempotent.

```text
/lore:config
```

## What it edits

| Setting | What it does |
|---------|--------------|
| **Project site URL** | The live product website. Optionally added to your trusted sources. |
| **Product description** | A short description of the product. Lore rewrites the home page (`docs/intro.md`) into a real introduction from it, and sets the site tagline. |
| **Trusted sources** | The approved, authoritative sources for documentation — Help Center, blog, live product, etc. |
| **Document-writing template** | Use the bundled default, or point to a custom template file. |
| **Brand color** | A hex color; regenerates the primary color shades in the Docusaurus styling. |
| **Product name** | Re-applied everywhere — titles, configuration, headings. |
| **Documentation language** | Re-applies styling (RTL or LTR) and updates the viewer's localization. |
| **Docusaurus on/off** | Turn the viewer on (runs [add-docusaurus](../guides/add-docusaurus.md)) or off (removes the viewer, keeps the docs). |

## Trusted sources matter

The trusted sources you configure become **authoritative**: skills prefer them over external knowledge and will not deliver documentation that contradicts them. Defining them well is the single biggest lever on documentation accuracy — see [Definition of Done](../concepts/definition-of-done.md).

## When to use it

- Right after `/lore:init`, to flesh out the project.
- Whenever the product's sources, roles, brand, or language change.
- To switch a docs-only project to a browsable site, or back.
