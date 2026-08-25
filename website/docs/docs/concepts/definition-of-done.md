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
| **Exhaust every source** *(blocking)* | Review every available input before writing; never write without examining what you have. Every run records what it read — including every configured trusted source — in an auditable source census, so no source can be silently skipped. What makes a row count is the [evidence rules](#evidence-not-attestation) below. |
| **Trusted sources** *(blocking)* | Base everything on approved sources; don't invent facts or rely on unverified third parties. |
| **Scope & structure** | Valid frontmatter; the document follows the canonical template. |
| **User roles** | Use the product's approved role names; explain role differences. |
| **Scenarios** *(blocking)* | Purpose, preconditions, flow, and postconditions; images inline at the right step. |
| **Accuracy** | Consistent terminology; UI labels match the source; rules are explicit, not vague. |
| **Technical validity** *(blocking)* | Working links, correct image paths, no misplaced images, a clean build. |
| **Language & style** | Content in the project's language; English file and directory names; a product-focused tone. |
| **Final report** *(blocking)* | A closing report of sources used, tools used, and a summary. |

## Evidence, not attestation

The "exhaust every source" rule used to be discharged by *writing a sentence*, and no sentence was ever compared against a machine-observable fact. `nothing relevant — confirmed searched` reads identically whether a source was read closely or never opened — and the agent that skipped it is the one writing the sentence. So it always passed.

Four sub-rules make that claim falsifiable. Each is **blocking**:

| Rule | What it requires |
|------|------------------|
| **Receipts** | A census row is a *claim*, and a claim needs a receipt: the probe that ran, its HTTP status, the bytes returned, and the on-disk path of the saved raw response. The words *confirmed*, *verified* and *checked* carry no evidentiary weight anywhere. Nor does your own published documentation: a page you wrote is not evidence about the product, however much it resembles a source — and a *fix* is a new claim, carrying the same obligation as the claim it replaces. |
| **Negative results** | A zero is the cheapest result to produce and the one that silently subtracts content — a broken probe and a genuinely empty source return the same string. A zero is valid only beside a successful receipt **and** a corroboration from the raw payload itself. If the payload has the data and the parse returned nothing, that is a **parser failure, not an absence**. And before any "not found" is believed, a **control** must pass: the same search, over the same paths, for something already known to be there. A search can come back empty because it skipped a directory or because the text is stored in an escaped form — both look exactly like an empty source. |
| **No assumed inaccessibility** | A source may be called login-gated or unreachable only on an **observed** status code or auth wall — never inferred from a link's position, a name, or a guess. |
| **Run contract** | Instructions you give in conversation ("cover the signed-in state too", "include the mobile view") are as binding as any configured source, and the easiest thing to lose because nothing on disk remembers them. They are written down at pre-flight as numbered rows and must each end the run *satisfied, with evidence* — or explicitly waived by you. |

The census is not optional: a run that produced documentation and left no census has proved nothing, and delivery is blocked. What makes these rules real rather than aspirational is that they are checked against artifacts the [enforcement hooks](./enforcement-hooks.md) wrote — not against prose.

## Auto-validation

Before delivery, output is validated against the DoD. If a blocking area fails, the work is not delivered — the failure is reported with what's required to fix it. The [`lore:doc-reviewer`](../guides/review-and-validate.md) skill and the `lore:doc-validator` subagent both apply this exact standard, so the same bar is enforced whether a human asks for a review or a producer skill self-checks at completion.

That first review is routine. What happens afterwards is deliberately bounded: **a green verdict ends the delivery**, fixes go in as one batch followed by a single scoped re-review, and any edit made after a green verdict comes back to *you* with its risk rather than triggering another round on its own. Two consecutive rounds whose findings were introduced by the previous round's fixes stop the process for a human decision. See [Review & validate](../guides/review-and-validate.md) for how this plays out in practice.

## Lessons learned

Issues encountered during a task are recorded as durable lessons with their root cause and fix, then checked before similar work in the future — so the same mistake is not made twice.
