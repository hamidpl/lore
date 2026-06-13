---
sidebar_position: 3
title: Enforcement hooks
description: Deterministic, blocking hooks that catch documentation errors on every file write and at project completion.
tags: [concepts, hooks, enforcement]
---

# Enforcement hooks

Skills and subagents do the writing; **hooks make the rules deterministic.** Lore ships shell-script hooks that run automatically — on every file write, and at project completion — and *block* the work when a rule is violated, feeding back exactly what to fix.

Because they are bundled with the plugin, they apply to every repository that installs Lore.

## On every write

| Hook | Blocks when… |
|------|--------------|
| **Frontmatter check** | A documentation file is missing its required frontmatter (a closed YAML block with the expected keys). |
| **Image-path check** | An image is written into the docs folder, or a Markdown image reference uses the wrong path prefix. |
| **Tooling-reference check** | A published doc mentions the authoring tooling — internal paths, configuration citations, or skill names. (Reader-facing output stays self-contained — see [Division of responsibility](../concepts/division-of-responsibility.md).) |

## At completion

A **Stop** hook does a final sweep: it blocks on misplaced images and bad image-reference paths, and warns about images that nothing references. It is loop-aware, so it won't trap you on an unfixable violation.

## Scope and safety

- Hooks act only on the project's documentation folder, resolved relative to the project root. Intentional examples (under template and configuration directories) are carved out and skipped.
- Parsing degrades gracefully across available tools and warns loudly if none is present, rather than silently passing.

The result: the most common documentation mistakes — wrong image paths, missing frontmatter, tooling leaks — are caught immediately and consistently, not at review time.
