---
sidebar_position: 1
title: Division of responsibility
description: The golden rule — the plugin carries product-agnostic methodology; the consuming repo carries product-specific configuration.
tags: [concepts, architecture]
---

# Division of responsibility

This is the core design principle of Lore, and every other decision follows from it.

> Lore carries **the product-agnostic methodology and the always-on rules**. Only product-specific *data* lives in the consuming repository.

| Layer | Lives in | Examples |
|-------|----------|----------|
| Product-agnostic methodology + always-on rules | **The plugin** | Skills, review subagents, enforcement hooks, the authoring template, and the Definition of Done (General Rules + §0/§2/§4–§8) |
| Product-specific data | **The consuming repo** | Trusted sources, user roles, product overview, document structure, language |

Change the methodology once in the plugin, and it propagates to every repository with a single update. Configure sources, roles, and structure per product, owned by the team that ships it.

The always-on rules ship as a plugin-owned `lore-methodology.md`; each repo's thin `CLAUDE.md` imports it and adds the product layer (plus any custom project rules). A `SessionStart` hook re-syncs the file on update — so rule improvements reach existing projects automatically, not just new ones.

## Reference, don't restate

Skills refer to the consuming repo's rules **by section number** — they never restate or hard-code a product's sources, roles, or structure. That indirection is what lets one skill serve every product.

## Single place of truth

A closely related rule governs facts everywhere: **every fact exists in exactly one canonical location, and everywhere else references it.** Copying the full text of a rule into a second place is prohibited. Canonical homes are, for example:

- Global rules and the Definition of Done (§0/§2/§4–§8) → the plugin-owned `lore-methodology.md`
- Product-layer configuration (trusted sources, roles) → the consuming repo's `CLAUDE.md`
- Input-specific workflow → the relevant skill
- Document structure → the project's document template

This keeps the methodology DRY across many repositories: there is one place to change anything, and no stale duplicates to drift out of sync.

## Reader-facing output

Because the published documentation is for the product's readers, it never mentions the authoring tooling — not Lore, not the skills, not the internal authoring artifacts. When a published doc needs a fact that lives in configuration, it states the fact directly. This boundary is enforced automatically by an [enforcement hook](../concepts/enforcement-hooks.md).
