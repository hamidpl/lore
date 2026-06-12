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
output follows the project's documentation language (§7).
-->

# Task Comments (Current Behavior)

## Introduction & Purpose

This document records how **task comments** behave in the live product today, including the exact messages the system shows. It documents what **is**, not what is planned.

## Scope

Covers posting, editing, and deleting a comment on a task, plus the empty state and validation. Reactions and @-mentions appear in the UI but are documented separately.

## Audiences & Roles

| Role | Observed access |
|------|-----------------|
| Owner | Post, edit own, delete any comment. |
| Editor | Post, edit own, delete own comment. |
| Viewer | Read comments only; no comment box shown. (Could not test Viewer for delete — no UI present.) |

## Key Performance Indicators (KPIs)

- Share of tasks that receive at least one comment.

## Terms & Definitions

- **Comment box** — the multi-line input at the bottom of a task's detail panel.

# Business Rules

Observed in the live product:

- The comment box is shown only to Owner and Editor; a Viewer sees the thread without an input box.
- An empty comment cannot be posted: the **Post** button stays disabled until the box is non-empty.
- A comment longer than the limit is blocked at input — typing stops at **2,000** characters and a counter turns red as it approaches the limit.

# Scenarios

## Scenario: Post a comment (happy path)

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

**Postconditions:** the comment is visible to everyone with access to the task.

## Scenario: Empty state (no comments yet)

**Purpose:** document the thread before any comment exists.

**Roles Involved:** Owner, Editor, Viewer.

**Preconditions:** the task has no comments.

**Main Flow:**

1. The member opens a task with no comments.

   ![Task comment thread empty state](/img/tasks/comments-03-empty-state.png)

2. The system shows the text **"No comments yet. Start the conversation."** Owner/Editor also see the comment box; Viewer sees only the message.

**Postconditions:** none.

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
- No console errors on the happy path. Posting with the network throttled showed a spinner on **Post** and a "Couldn't post comment. Retry." inline message on timeout.

# Dependencies & Prerequisites

- Depends on the **Comments** API; the thread degrades to a read-only "Comments are temporarily unavailable" notice when the API errors.

# Roadmap

- The 5,000-character design (see discrepancy) is a candidate for a later release, pending product confirmation.

# Appendix & Resources

- Compared against Figma *Comments v2* for the discrepancy section.

---

# Final Report

**1. Sources Used**

- Primary input: live product observation (browser-driven via Playwright MCP).
- URLs tested: the task detail page of a sample project.
- Scenario scripts: `.claude/scenarios/comments.yaml`.
- Images captured: 3 → `static/img/tasks/`.
- Trusted sources: none configured for this example.

**2. Tools and Skills Used**

- Skill: `lore:site-to-doc`. Subagents: `lore:site-explorer` (ran the scenario, captured screenshots, collected console/network detail), `lore:doc-validator` (returned APPROVED WITH WARNINGS — one open discrepancy).

**3. Summary**

- URLs tested: task detail page. Test environment: Chromium, viewport 1280×720, macOS, normal + throttled network, observed on the documentation date.
- Authentication: reused a persistent logged-in session (manual Login Checkpoint done once); no secret handled.
- Roles tested: Owner, Editor. Could not fully test Viewer delete (no UI present) — noted.
- Screenshots captured: 3 (`static/img/tasks/`), named `comments-NN-state.png`.
- Budget used: 1 scenario / 3 pages (within the ~3-scenario / ~10-page default).
- Discrepancy found: live comment length 2,000/silent vs. design 5,000/toast — flagged and sent to product.
- Edge cases tested: empty state, max length, network timeout.
