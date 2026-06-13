---
sidebar_position: 2
title: The Definition of Done
description: The shared quality bar every document must meet — sources, structure, scenarios, accuracy, technical validity, language, and a final report.
tags: [concepts, quality, definition-of-done]
---

# The Definition of Done

Every Lore project carries a **Definition of Done (DoD)** — the quality bar a document must clear before it is delivered. Several of its sections are **blocking**: if any blocking section fails, the work is not done.

The DoD lives in the consuming repository so each product can tune it, but the shape is shared:

| Area | What it requires |
|------|------------------|
| **Pre-writing** *(blocking)* | Review every available input before writing; never write without examining what you have. |
| **Trusted sources** *(blocking)* | Base everything on approved sources; don't invent facts or rely on unverified third parties. |
| **Scope & structure** | Valid frontmatter; the document follows the canonical template. |
| **User roles** | Use the product's approved role names; explain role differences. |
| **Scenarios** *(blocking)* | Purpose, preconditions, flow, and postconditions; images inline at the right step. |
| **Accuracy** | Consistent terminology; UI labels match the source; rules are explicit, not vague. |
| **Technical validity** *(blocking)* | Working links, correct image paths, no misplaced images, a clean build. |
| **Language & style** | Content in the project's language; English file and directory names; a product-focused tone. |
| **Final report** *(blocking)* | A closing report of sources used, tools used, and a summary. |

## Auto-validation

Before delivery, output is validated against the DoD. If a blocking area fails, the work is not delivered — the failure is reported with what's required to fix it. The [`lore:doc-reviewer`](../guides/review-and-validate.md) skill and the `lore:doc-validator` subagent both apply this exact standard, so the same bar is enforced whether a human asks for a review or a producer skill self-checks at completion.

## Lessons learned

Issues encountered during a task are recorded as durable lessons with their root cause and fix, then checked before similar work in the future — so the same mistake is not made twice.
