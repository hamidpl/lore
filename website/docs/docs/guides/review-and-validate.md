---
sidebar_position: 4
title: Review & validate
description: Use lore:doc-reviewer and the doc-validator subagent to check documentation against the Definition of Done before delivery.
tags: [guides, review, quality]
---

# Review & validate

Use **`lore:doc-reviewer`** to validate documentation against the [Definition of Done](../concepts/definition-of-done.md) — before delivery, or to audit existing files.

```text
lore:doc-reviewer <file-or-folder>
```

## What it checks

The reviewer works through the Definition of Done area by area, verifying the technical points concretely rather than by eye:

- **Sources** — facts trace back to approved sources; nothing fabricated.
- **Structure** — valid frontmatter; all required sections present.
- **Scenarios** — each is numbered (`Scenario 1`, `Scenario 2`, …) and has purpose, preconditions, flow, and postconditions, with images inline at the right step; a Mobile & Tablet View section is present whenever the doc uses responsive screenshots. A scenario with no extensions (its error and edge branches) is flagged as a warning, and extension coverage is compared against the documentation template's edge-case taxonomy.
- **Accuracy** — consistent terminology; UI labels match the source; rules are explicit.
- **Technical validity** — internal links work; image references and storage paths are correct; no images in the wrong place; and the site builds with no errors.
- **Language & style**, and a complete **final report**.

## The verdict

Every review ends with one of three outcomes:

| Verdict | Meaning |
|---------|---------|
| ✅ **Approved for delivery** | No blocking failures. |
| ⚠️ **Approved with warnings** | No blocking failures; non-blocking issues noted. |
| ❌ **Blocked — do not deliver** | Blocking failures, each listed with a specific fix. |

## Automatic self-verification

You rarely run this by hand for fresh output: every producer skill ([figma](../guides/from-figma.md), [brief](../guides/from-a-brief.md), [site](../guides/from-a-live-site.md)) invokes the read-only **`lore:doc-validator`** subagent at completion. The validator applies the same method, runs the concrete technical checks, and returns the structured report — so quality is gated before anything is delivered. Run `lore:doc-reviewer` yourself to audit older documents or a whole folder.
