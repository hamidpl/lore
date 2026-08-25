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

You rarely run this by hand for fresh output: every producer skill ([figma](../guides/from-figma.md), [brief](../guides/from-a-brief.md), [site](../guides/from-a-live-site.md)) invokes the read-only **`lore:doc-validator`** subagent at completion. The validator applies the same method, runs the concrete technical checks, and returns the structured report — so quality is gated before anything is delivered. That first review is routine and happens without asking. Run `lore:doc-reviewer` yourself to audit older documents or a whole folder.

## How many rounds this should take

**One review, then fixes, then at most one more.** If you are watching review after review go by, something is wrong with the process rather than with the document — and Lore is built to stop that rather than ride it out.

Three rules do the work:

- **A green verdict ends the delivery.** Anything edited afterwards is new, unreviewed work — whatever its size. The turn stops and you are asked what to do, with the risk spelled out: re-review just the changed files, or approve delivering them as they are. What you approve is tied to that exact content, so a later edit quietly retires the approval.
- **Fixes go in as one batch, and files are not edited mid-review.** Interleaving fixes with reviews is what turns one delivery into seven: in the run that produced these rules, four of seven rounds found problems that had not existed the round before, and the only two rounds that came back clean were the two where the fixes landed together and nothing moved underneath the reviewer.
- **Two rounds in a row caused by the previous round's fixes means stop.** You get told, with the round count, instead of a third attempt. Each finding is labelled as either pre-existing or introduced since the last green review, so "the reviewer keeps complaining" is visibly distinct from "our fixes keep breaking things".

The reviewer itself never edits anything — it is read-only, and always was. Every fix is made by the main agent under the rules above, which is precisely where the loop used to come from.

Two things it cannot do, honestly stated: a review is sampling, not proof — the list of things one could check is unbounded — and some checks only become possible once earlier ones are settled. So a second round is sometimes legitimate. A fourth is a signal.
