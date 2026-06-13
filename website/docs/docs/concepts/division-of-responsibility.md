---
sidebar_position: 1
title: Division of responsibility
description: The golden rule — the plugin carries product-agnostic methodology; the consuming repo carries product-specific configuration.
tags: [concepts, architecture]
---

# Division of responsibility

This is the core design principle of Lore, and every other decision follows from it.

> Lore carries **only the product-agnostic methodology**. Everything product-specific lives in the **consuming repository**.

| Layer | Lives in | Examples |
|-------|----------|----------|
| Product-agnostic methodology | **The plugin** | Skills, review subagents, enforcement hooks, the authoring template |
| Product-specific configuration | **The consuming repo** | Definition of Done, trusted sources, user roles, document structure, language |

Change the methodology once in the plugin, and it propagates to every repository with a single update. Configure sources, roles, and structure per product, owned by the team that ships it.

## Reference, don't restate

Skills refer to the consuming repo's rules **by section number** — they never restate or hard-code a product's sources, roles, or structure. That indirection is what lets one skill serve every product.

## Single place of truth

A closely related rule governs facts everywhere: **every fact exists in exactly one canonical location, and everywhere else references it.** Copying the full text of a rule into a second place is prohibited. Canonical homes are, for example:

- Global rules and the Definition of Done → the consuming repo's configuration
- Input-specific workflow → the relevant skill
- Document structure → the project's document template

This keeps the methodology DRY across many repositories: there is one place to change anything, and no stale duplicates to drift out of sync.

## Reader-facing output

Because the published documentation is for the product's readers, it never mentions the authoring tooling — not Lore, not the skills, not the internal authoring artifacts. When a published doc needs a fact that lives in configuration, it states the fact directly. This boundary is enforced automatically by an [enforcement hook](../concepts/enforcement-hooks.md).
