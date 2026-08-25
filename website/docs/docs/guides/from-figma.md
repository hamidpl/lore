---
sidebar_position: 1
title: Document from Figma
description: Use lore:figma-to-doc to turn Figma design files, Dev-Mode annotations, comments, and prototype wiring into documented flows and business rules with inline screenshots.
tags: [guides, figma]
---

# Document from Figma

Use **`lore:figma-to-doc`** when your input is visual: design files, mockups, or anything with a Figma link.

```text
lore:figma-to-doc <figma-url-or-file-key>
```

## What it does

1. **Collects sources.** Fetches the file's discussion **comments** and its **Dev-Mode annotations** (the `annotations` property on nodes — Figma's real annotation feature, distinct from ordinary design text) — these are two separate sources, and both are read. It also searches your configured trusted sources for material about the pages in scope. Everything — comments, annotations, and each trusted source's findings — is recorded in an auditable source census, every row carrying the [receipt](../concepts/definition-of-done.md#evidence-not-attestation) behind it, so no source can be silently skipped.

   Fetching goes through a probe script that saves the raw response *before* anything interprets it and selects annotations on the **presence of the `annotations` array**, never on a field name inside it. That shape is undocumented and has changed: keying on one field name once turned a schema drift into a confident "0 annotations — confirmed none", deleting every business rule the designers had written. When the saved payload contains annotation data the parse missed, the probe says so and that counts as a **failed read, not a zero**.
2. **Reviews the design.** Navigates every frame, skips pages marked out of scope, and summarizes the business rules expressed in annotations and comments.
3. **Reads the prototype wiring.** Fetches the file's prototype flows (`flowStartingPoints`) and each frame's `interactions[]` — the machine-readable *navigation* evidence for a scenario's Main Flow, instead of guessing the flow from frame names. Animation timing (duration, easing, transition type) is deliberately ignored as presentation noise; only the navigation meaning is kept (e.g. an overlay transition ⇒ a dialog). The flow/interaction counts are recorded in the source census, even when zero.
4. **Extracts images.** Exports **individual frames** (never whole-section composites) at 2× resolution and stores them under the static image directory, named by feature and state. Frames are classified by device (from their width and name); mobile and tablet variants are routed to `mobile/` and `tablet/` sub-paths. Once every frame has landed, they are compressed in a single pass — typically around 70% smaller, at the same dimensions and with no visible difference. These files are committed to your repository and served by your site, so this is the only point where that weight is reclaimed. The compressor refuses to write a file it cannot compress within its quality floor, so "smaller" never quietly means "worse"; if no image optimizer is installed on the machine, the run says so and leaves the images untouched rather than claiming a saving it didn't make.
5. **Writes the documentation.** Maps Figma pages to doc sections, frame groups to numbered scenarios (`Scenario 1`, `Scenario 2`, …), annotations to business rules, component variants to role differences, and prototype interactions to Main Flow steps — adding a Mermaid flow diagram to any section with two or more interaction edges. When the design includes mobile or tablet frames, a short **Mobile & Tablet View** section captures what differs from desktop (mobile screenshots render at half width so tall phone shots don't dominate the page).
6. **Validates and reports.** Runs the [doc validator](../guides/review-and-validate.md) before delivery and ends with a source/tooling/summary report.

## Heavy extraction is delegated

For large files, the heavy lifting (comments, annotations, the frame inventory, and frame image export) is handled by the **`lore:figma-extractor`** subagent, which returns a compact summary of business rules and image paths. This keeps the main session's context clean. See [Skills & subagents](../reference/skills-and-subagents.md).

## Handling gaps

- Missing information becomes an explicit `[CLARIFICATION NEEDED: …]` marker rather than a guess.
- Each documented feature's frames are checked against the states real usage produces — empty, error, loading, permission-denied. A state the design doesn't show becomes a clarification question, never an invented screen.
- Placeholder/Lorem-Ipsum text prompts a request for the real content.
- When an annotation and a comment conflict, the annotation is preferred and the conflict is raised with you.
- Prototype wiring is treated as *design intent, not confirmed behavior*: where an interaction edge contradicts a Dev-Mode annotation, the annotation wins and the divergence is called out.

## Credentials

The Figma token is read from the environment or the connected integration. It is never requested in chat, echoed, or written to a file.
