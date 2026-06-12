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
the project's documentation language (§7).
-->

# Bulk Task Import

## Introduction & Purpose

**Bulk Task Import** lets an Editor or Owner create many tasks at once by uploading a CSV file, instead of adding them one by one.

**Business goal:** lower the effort of moving an existing backlog into the product, which the epic identifies as the top friction point for teams migrating from spreadsheets.

## Scope

Covers uploading a CSV, mapping its columns to task fields, validating rows, and committing the import. Out of scope (stated in the epic): recurring/scheduled imports and imports from external tools' APIs.

## Audiences & Roles

| Role | Access |
|------|--------|
| Owner | Can import. |
| Editor | Can import. |
| Viewer | Cannot import (no access to the action). |

## Key Performance Indicators (KPIs)

- Share of new projects that use import within their first week.
- Median rows per successful import.

## Terms & Definitions

- **Mapping** — the association between a CSV column and a task field (title, status, assignee).
- **Row error** — a CSV row that fails validation and is excluded from the committed import.

# Business Rules

Derived from the epic's acceptance criteria:

- **AC-1 → Rule:** the **title** column is required; a row with an empty title is a row error and is not imported.
- **AC-2 → Rule:** an import accepts at most **500** rows per file. [CLARIFICATION NEEDED: is 500 a hard limit that blocks the upload, or are the first 500 imported and the rest reported?]
- **AC-3 → Rule:** a status value that is not one of the project's defined statuses is a row error; the row is excluded and reported.
- **AC-4 → Rule:** the import is **all-or-nothing per valid row** — valid rows commit even if some rows have errors; the user sees a summary of imported vs. excluded counts.

# Scenarios

## Scenario: Import a CSV with some invalid rows

**Purpose:** an Editor uploads a CSV in which most rows are valid and a few fail validation.

**Roles Involved:** Owner, Editor.

**Preconditions:** the member is in a project and has a CSV file with a header row.

**Main Flow:**

1. The member opens **Tasks → Import** and selects a CSV file.
2. The system reads the header and asks the member to map columns to fields (title, status, assignee).
3. The member confirms the mapping and clicks **Validate**.
4. The system shows a preview: count of valid rows and a list of row errors with reasons. [CLARIFICATION NEEDED: does the preview show all error rows, or only the first N?]
5. The member clicks **Import valid rows**.
6. The system creates the valid tasks and shows a summary: "X tasks imported, Y rows skipped".

**Postconditions:** the valid tasks exist in the project; skipped rows are not created. The uploaded file is not retained. [CLARIFICATION NEEDED: is the source file stored, or discarded after import?]

## Scenario: Upload exceeds the row limit

**Purpose:** document what happens when the file has more rows than allowed.

**Roles Involved:** Owner, Editor.

**Preconditions:** the member selects a CSV with more than 500 data rows.

**Main Flow:**

1. The member selects the oversized file.
2. The system reports that the file exceeds the per-import limit. [CLARIFICATION NEEDED: exact message wording and whether the upload is blocked or truncated — see Rule AC-2.]

**Postconditions:** no tasks are created until the member uploads a file within the limit.

# Dependencies & Prerequisites

- Requires the project's **status set** to be defined (AC-3 validates against it).
- Depends on the **Tasks** service to create tasks transactionally per valid row.

# Roadmap

- A later phase may add scheduled/recurring imports (explicitly deferred by the epic).

# Appendix & Resources

- Source epic: *EPIC-214 Bulk Task Import* (v1.2). User stories US-214-1 … US-214-4.

---

# Final Report

**1. Sources Used**

- Primary input: epic *EPIC-214 Bulk Task Import*, v1.2, authored by the product team.
- User stories addressed: US-214-1 through US-214-4. Acceptance criteria used: AC-1 … AC-4.
- No images (no visual design provided).
- Trusted sources: none configured for this example.

**2. Tools and Skills Used**

- Skill: `lore:brief-to-doc`. Subagent: `lore:doc-validator` (returned APPROVED WITH WARNINGS — see pending questions).
- Files added: `docs/tasks/import.md`.

**3. Summary**

- Added the Bulk Task Import document with two scenarios and four acceptance-criteria-derived business rules.
- No features were invented; every gap is marked `[CLARIFICATION NEEDED]`.

**Clarifications log**

- Pending: 500-row limit behavior (block vs. truncate); preview error-row cap; source-file retention; exact over-limit message. All four are reflected as `[CLARIFICATION NEEDED]` markers in the document and were sent to the product owner.
