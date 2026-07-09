---
sidebar_position: 4
title: Task Comments (Current Behavior)
description: How commenting on a task actually works in the live product, captured by direct observation.
tags: [tasks, comments]
---

<!--
EXAMPLE OUTPUT for the lore:site-to-doc skill.
Shown for an English-language project documenting a generic project-management
product by observing the running site. UI text is captured verbatim. Your real
output follows the project's documentation language (§7). The page title comes
from the frontmatter `title` above — the body starts at the Document Info block,
with no `#` (H1) heading.
-->

| Field | Value |
|-------|-------|
| **Status** | Current |
| **Owner** | Tasks team |
| **Last verified** | 2025-05-22 — against the live product (observed) |

## Introduction & Purpose

This document records how **task comments** behave in the live product today, including the exact messages the system shows. It documents what **is**, not what is planned.

## Scope

Covers posting, editing, and deleting a comment on a task, plus the empty state and validation.

**Out of scope:** reactions and @-mentions (they appear in the UI but are documented separately).

## Audiences & Roles

| Role | Observed access |
|------|-----------------|
| Owner | Post, edit own, delete any comment. |
| Editor | Post, edit own, delete own comment. |
| Viewer | Read comments only; no comment box shown. (Could not test Viewer for delete — no UI present.) |

## Success signals (KPIs)

- Share of tasks that receive at least one comment.

## Terms & Definitions

- **Comment box** — the multi-line input at the bottom of a task's detail panel.

## Business Rules

Observed in the live product:

- **BR-1** — The comment box is shown only to Owner and Editor; a Viewer sees the thread without an input box.
- **BR-2** — An empty comment cannot be posted: the **Post** button stays disabled until the box is non-empty.
- **BR-3** — A comment longer than the limit is blocked at input — typing stops at **2,000** characters and a counter turns red as it approaches the limit.

## Scenarios

1. **Post a comment** — add a comment to a task, including the empty state and validation.

### Scenario 1: Post a comment

**Purpose:** an Editor adds a comment to a task.

**Roles Involved:** Owner, Editor.

**Preconditions:** the member is signed in and viewing a task they can edit.

**Main Flow:**

1. The member opens a task and scrolls to the comment box.

   ![Task detail with empty comment box](/img/tasks/comments-01-initial.png)

2. The member types a comment. The **Post** button enables.
3. The member clicks **Post**.
4. The system appends the comment to the thread with the author and a relative timestamp ("just now").

   ![Comment posted and shown in the thread](/img/tasks/comments-02-posted.png)

**Extensions — Alternative & Exception Flows:**

- **1a.** The task has no comments yet (empty state):
  - **1a1.** The system shows the text **"No comments yet. Start the conversation."** Owner/Editor also see the comment box; a Viewer sees only the message (BR-1).

    ![Task comment thread empty state](/img/tasks/comments-03-empty-state.png)

- **2a.** The comment box is empty (BR-2):
  - **2a1.** The **Post** button stays disabled; nothing is posted.
- **2b.** The member reaches the length limit (BR-3):
  - **2b1.** Input stops accepting characters at **2,000**; the counter turns red as it nears the limit. There is no over-limit message — input simply stops.
- **3a.** The network times out while posting:
  - **3a1.** The **Post** button shows a spinner, then an inline message **"Couldn't post comment. Retry."**; the comment is not added.

**Postconditions:** the comment is visible to everyone with access to the task.

## Mobile & Tablet View

On the mobile viewport (`390×844`) the task detail differs from desktop only in layout — the flow in Scenario 1 is unchanged:

- The comment thread and the composer stack in a single column; the composer docks to the bottom of the screen and the **Post** button becomes a full-width icon button.
- The task's side metadata panel (assignee, labels) collapses behind a **"Details"** toggle at the top instead of showing in a right rail.

<img src="/img/tasks/mobile/comments-01-initial.png" alt="Task detail and comment composer on mobile" />

Tablet (`768×1024`) keeps the desktop two-column layout at a narrower width; no behavioral differences observed.

## Behavior vs. design discrepancy

**Observed in the live product:**

- Maximum comment length: **2,000** characters (input blocks beyond it).
- Over-limit message: none — input simply stops accepting characters.

**Designed (Figma "Comments v2"):**

- Maximum length: 5,000 characters, with an explicit error toast on overflow.

**Status:** ⚠️ The live limit (2,000, silent) differs from the design (5,000, with a toast). Documented the current behavior. [CLARIFICATION REQUESTED: keep documenting 2,000/silent, or is the 5,000/toast design shipping soon?]

## Technical Details

Observed in the browser console while posting:

- Endpoint: `POST /api/tasks/{id}/comments`, request `{ "body": "..." }`, response `201` with the created comment.
- No console errors on the happy path. Posting with the network throttled reproduced extension 3a (spinner → "Couldn't post comment. Retry.").

## Dependencies & Prerequisites

- Depends on the **Comments** API; the thread degrades to a read-only "Comments are temporarily unavailable" notice when the API errors.

## Roadmap

- The 5,000-character design (see discrepancy) is a candidate for a later release, pending product confirmation.

## Changelog

| Date | Change | Source |
|------|--------|--------|
| 2025-05-22 | Initial version — posting, empty state, validation, and the live-vs-design length discrepancy | Live product (observed) + Figma *Comments v2* |

## Appendix & Resources

- Compared against Figma *Comments v2* for the discrepancy section.

<!--
The Final Report (CLAUDE.md §8) is delivered IN CHAT at task completion — it is a
process deliverable for the user and is NEVER written into the documentation file.
It names the skill, subagents, and internal .claude/ paths, none of which may appear
in reader-facing docs (Rule 5). It is intentionally omitted from this example file.
-->
