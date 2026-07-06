---
sidebar_position: 3
title: Bulk Task Import
description: Importing tasks from a CSV file, documented from the product epic and its acceptance criteria.
tags: [tasks, import]
---

<!--
EXAMPLE OUTPUT for the lore:brief-to-doc skill.
Shown for an English-language project documenting a generic project-management
product, generated from a written epic (no visual design). [CLARIFICATION NEEDED]
markers stand in for details the brief did not specify. Your real output follows
the project's documentation language (§7). The page title comes from the
frontmatter `title` above — the body starts at the Document Info block, with no
`#` (H1) heading.
-->

| Field | Value |
|-------|-------|
| **Status** | Draft |
| **Owner** | Tasks team |
| **Last verified** | 2025-05-20 — against epic *EPIC-214 Bulk Task Import* (v1.2) |

## Introduction & Purpose

Before this existed, a team migrating from spreadsheets had to re-enter its whole backlog one task at a time — the epic identifies this as their top friction point. **Bulk Task Import** lets an Editor or Owner create many tasks at once by uploading a CSV file.

**Business goal:** lower the effort of moving an existing backlog into the product, to reduce drop-off during team migration.

## Scope

Covers uploading a CSV, mapping its columns to task fields, validating rows, and committing the import.

**Out of scope (non-goals)** — stated in the epic: recurring/scheduled imports and imports from external tools' APIs.

## Audiences & Roles

| Role | Access |
|------|--------|
| Owner | Can import. |
| Editor | Can import. |
| Viewer | Cannot import (no access to the action). |

## Success signals (KPIs)

- Share of new projects that use import within their first week.
- Median rows per successful import.

## Terms & Definitions

- **Mapping** — the association between a CSV column and a task field (title, status, assignee).
- **Row error** — a CSV row that fails validation and is excluded from the committed import.

## Business Rules

Derived from the epic's acceptance criteria:

- **BR-1** (AC-1) — the **title** column is required; a row with an empty title is a row error and is not imported.
- **BR-2** (AC-2) — an import accepts at most **500** rows per file. (See Open Questions — hard block vs. truncate.)
- **BR-3** (AC-3) — a status value that is not one of the project's defined statuses is a row error; the row is excluded and reported.
- **BR-4** (AC-4) — the import is **all-or-nothing per valid row**: valid rows commit even if some rows have errors; the user sees a summary of imported vs. excluded counts.

## Scenarios

- **Import tasks from a CSV file** — upload, map, validate, and commit an import.

### Import tasks from a CSV file

**Purpose:** an Editor uploads a CSV to create many tasks at once.

**Roles Involved:** Owner, Editor.

**Preconditions:** the member is in a project and has a CSV file with a header row.

**Main Flow:**

1. The member opens **Tasks → Import** and selects a CSV file.
2. The system reads the header and asks the member to map columns to fields (title, status, assignee).
3. The member confirms the mapping and clicks **Validate**.
4. The system shows a preview: the count of valid rows and any row errors with reasons.
5. The member clicks **Import valid rows**.
6. The system creates the valid tasks and shows a summary: "X tasks imported, Y rows skipped" (BR-4).

**Extensions — Alternative & Exception Flows:**

- **1a.** The selected file exceeds the per-import limit (more than 500 data rows — BR-2):
  - **1a1.** The system reports that the file exceeds the limit and does not proceed. (See Open Questions — exact wording and block-vs-truncate.)
- **4a.** Some rows fail validation (empty title — BR-1, or an unknown status — BR-3):
  - **4a1.** The system lists the row errors with reasons in the preview and still offers **Import valid rows**. (See Open Questions — show all error rows or first N.)
- **5a.** Every row failed validation:
  - **5a1.** No valid rows remain; the system disables **Import valid rows** and prompts the member to fix the file.

**Postconditions:** the valid tasks exist in the project; skipped rows are not created.

## Open Questions

- 2025-05-20 — BR-2: is 500 a hard limit that blocks the upload, or are the first 500 imported and the rest reported? — waiting on product.
- 2025-05-20 — Extension 1a: exact message wording for the oversized-file case. — waiting on content.
- 2025-05-20 — Extension 4a: does the preview show all error rows, or only the first N? — waiting on design.
- 2025-05-20 — Is the uploaded source file retained after import, or discarded? — waiting on engineering.

## Dependencies & Prerequisites

- Requires the project's **status set** to be defined (BR-3 validates against it).
- Depends on the **Tasks** service to create tasks transactionally per valid row.

## Roadmap

- A later phase may add scheduled/recurring imports (explicitly deferred by the epic).

## Changelog

| Date | Change | Source |
|------|--------|--------|
| 2025-05-20 | Initial version from the epic and its acceptance criteria | EPIC-214 (v1.2) |

## Appendix & Resources

- Source epic: *EPIC-214 Bulk Task Import* (v1.2). User stories US-214-1 … US-214-4.

<!--
The Final Report (CLAUDE.md §8) is delivered IN CHAT at task completion — it is a
process deliverable for the user and is NEVER written into the documentation file.
It names the skill, subagents, and internal paths, none of which may appear in
reader-facing docs (Rule 5). It is intentionally omitted from this example file.
-->
