---
sidebar_position: 3
title: Template layers
description: The composable template layers Lore scaffolds — the docs layer, the Docusaurus base, and the RTL assets.
tags: [reference, templates]
---

# Template layers

When Lore scaffolds a project it composes independent, optional layers. They are copied non-destructively — existing files are never overwritten. **`.gitignore` is the single exception:** every layer contributes entries to it, so it is *merged* rather than skipped. Only lines that are not already present are appended, so re-running is safe and your own entries are never touched.

| Layer | When | What it provides |
|-------|------|------------------|
| **Docs layer** | Always | The documentation folder, the project's configuration (including the Definition of Done), a lessons-learned log, a document template, and a `.gitignore`. |
| **Docusaurus base** | If you choose the viewer | The Docusaurus configuration, sidebar, and brand styling. The framework itself is fetched fresh, not bundled. |
| **RTL assets** | Viewer + a right-to-left language | The self-hosted Persian font and the right-to-left stylesheet. |

## The docs layer

The always-included foundation. It establishes *how* documentation is written and validated in this repository — the [Definition of Done](../concepts/definition-of-done.md), the image-path and frontmatter rules, and the canonical document structure — independent of whether you ever add a browsable site. The always-on rules live in a plugin-owned `lore-methodology.md` that the project's thin `CLAUDE.md` imports; a `SessionStart` hook keeps that file current on `/plugin update`, while `CLAUDE.md` holds your product-specific layer.

Its `.gitignore` is load-bearing rather than housekeeping. A live-site run can export an authenticated browser session to disk, and a session token committed to git history grants full impersonation of that account — permanently, since a later commit cannot remove it. The same file also keeps the run artifacts behind the census receipts (raw payloads, run logs) out of version control; **the census itself stays committed**, because it is the auditable record of what the run read.

## The Docusaurus base

An overlay, not the framework. Lore keeps its **configuration and styling** as a thin layer; the Docusaurus framework is pulled fresh with `create-docusaurus@latest` at scaffold time, so you always start on the current release. This is why the viewer is [added](../guides/add-docusaurus.md) rather than vendored.

## The RTL assets

Added only when both conditions hold — a viewer *and* a right-to-left documentation language. It supplies the [Vazirmatn font and the RTL layout](../concepts/multilingual-rtl.md) layered on top of the base styling.
