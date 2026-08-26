<!--
EXAMPLE OUTPUT for the lore:doc-reviewer skill.
This is a Review Report (the skill's deliverable), not product documentation, so
it carries no docs frontmatter. It shows a review that BLOCKS delivery because of
two ⛔ failures. Locations are illustrative.
-->

# 📋 Documentation Review Report

**Document:** docs/tasks/import.md
**Reviewed on:** 2026-06-12
**Overall Status:** ❌ FAIL

## Section Results

| DoD area | Status | Issue (location) |
|----------|--------|------------------|
| §0 Exhaust Every Source | ✅ | All manifest sources read; no trusted sources configured (not required). |
| §1 Trusted Sources | ✅ | No fabricated facts; gaps marked `[CLARIFICATION NEEDED]`. |
| §2 Scope & Structure | ⚠️ | Frontmatter valid and the Document Info block is present, but the required **Changelog** section is missing. |
| §3 User Roles | ✅ | Owner/Editor/Viewer documented with approved names. |
| §4 Scenarios | ❌ | "Import tasks from a CSV file" scenario has no **Postconditions** (line ~58), and its oversized-file case is written as a Main Flow step instead of an **Extension**. ⛔ |
| §5 Accuracy | ⚠️ | "around 500 rows" is vague — state the exact limit or mark it `[CLARIFICATION NEEDED]` (line ~33). |
| §6 Technical Validity | ❌ | Image reference uses `/static/img/tasks/import-preview.png` (line ~52); must be `/img/...`. ⛔ |
| §7 Language & Style | ✅ | Content language consistent; file/dir names are English kebab-case. |
| §8 Final Report | ✅ | Sources, Tools/Skills, and Summary all present. |
| Rule 3 Lessons | ✅ | No errors encountered this task; nothing to record. |
| Rule 4 Single Truth | ✅ | No global rule restated; references used. |

## Blocking Failures: 2

(§0, §1, §4, §6, §8, Rule 3, Rule 4)

- **§4 Scenarios** — a scenario is missing Postconditions (and an exception case is not captured as an Extension).
- **§6 Technical Validity** — an image is referenced via `/static/img/`.

## Recommendation

❌ **BLOCKED — DO NOT DELIVER**

## Required Actions (if blocked)

1. **§4 Scenario** — Class: content — Targets: docs/tasks/import.md#Scenario 2: Import tasks from a CSV file — Evidence: .claude/sources/brief-tasks-census.md row [b3] ("skipped rows are reported, not created"); the scenario's Main Flow step 6 in the page itself — Counter: the Postconditions could be read as implied by step 6, but the template makes the block mandatory (§4) — Provenance: pre-existing — Severity: blocking — Fix: add a **Postconditions** block stating that valid tasks are created and skipped rows are not, citing [b3]; move the oversized-file case into an **Extensions** block anchored to the upload step.
2. **§6 Image path** — Class: mechanical — Targets: docs/tasks/import.md#Scenario 2: Import tasks from a CSV file — Evidence: `test -f static/img/tasks/import-preview.png` → exists; `npm run build` → broken asset `/static/img/tasks/import-preview.png` — Counter: none; the build itself fails on this path — Provenance: pre-existing — Severity: blocking — Fix: old: «![preview](/static/img/tasks/import-preview.png)» new: «![preview](/img/tasks/import-preview.png)». The physical file stays at `static/img/tasks/import-preview.png`.

## Non-blocking warnings (address before next release)

- **§2** — add the missing **Changelog** section from the template.
- **§5** — replace "around 500 rows" with the exact, confirmed limit.

> Note: this project has Docusaurus installed, so `npm run build` was run as part of §6 — it surfaced the `/static/img/` reference as a broken asset path, confirming finding 2. For a docs-only project the build step would be marked **N/A** and the same reference caught by the manual grep check instead.
