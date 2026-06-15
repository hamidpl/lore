---
sidebar_position: 1
title: Document from Figma
description: Use lore:figma-to-doc to turn Figma design files, Dev-Mode annotations, and comments into documented flows and business rules with inline screenshots.
tags: [guides, figma]
---

# Document from Figma

Use **`lore:figma-to-doc`** when your input is visual: design files, mockups, or anything with a Figma link.

```text
lore:figma-to-doc <figma-url-or-file-key>
```

## What it does

1. **Collects sources.** Fetches the file's discussion **comments** and its **Dev-Mode annotations** (the `annotations` property on nodes — Figma's real annotation feature, distinct from ordinary design text) — these are two separate sources, and both are read. It records them in an auditable source census so nothing is silently skipped, and also searches your configured trusted sources.
2. **Reviews the design.** Navigates every frame, skips pages marked out of scope, and summarizes the business rules expressed in annotations and comments.
3. **Extracts images.** Exports **individual frames** (never whole-section composites) at 2× resolution and stores them under the static image directory, named by feature and state.
4. **Writes the documentation.** Maps Figma pages to doc sections, frame groups to scenarios, annotations to business rules, and component variants to role differences.
5. **Validates and reports.** Runs the [doc validator](../guides/review-and-validate.md) before delivery and ends with a source/tooling/summary report.

## Heavy extraction is delegated

For large files, the heavy lifting (comments, annotations, the frame inventory, and frame image export) is handled by the **`lore:figma-extractor`** subagent, which returns a compact summary of business rules and image paths. This keeps the main session's context clean. See [Skills & subagents](../reference/skills-and-subagents.md).

## Handling gaps

- Missing information becomes an explicit `[CLARIFICATION NEEDED: …]` marker rather than a guess.
- Placeholder/Lorem-Ipsum text prompts a request for the real content.
- When an annotation and a comment conflict, the annotation is preferred and the conflict is raised with you.

## Credentials

The Figma token is read from the environment or the connected integration. It is never requested in chat, echoed, or written to a file.
