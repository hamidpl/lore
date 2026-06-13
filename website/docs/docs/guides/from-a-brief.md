---
sidebar_position: 2
title: Document from a brief
description: Use lore:brief-to-doc to turn product briefs, PRDs, epics, and user stories into documentation, inferring scenarios from acceptance criteria.
tags: [guides, brief, prd]
---

# Document from a brief

Use **`lore:brief-to-doc`** when your input is written requirements — a product brief, PRD, epic, user story, or feature description, as text or a file.

```text
lore:brief-to-doc <brief-text-or-file>
```

## What it does

1. **Reads the brief end to end** and extracts every user story and acceptance criterion, identifying gaps and ambiguities up front.
2. **Asks clarifying questions** where behavior, rules, edge cases, or exact messages are unspecified.
3. **Infers scenarios** from user stories — turning *"As a [role], I want [action], so that [benefit]"* into a complete scenario with purpose, preconditions, flow, and postconditions.
4. **Converts acceptance criteria into explicit business rules**, making vague language specific.
5. **Validates and reports**, including a log of every clarification raised.

## Document what's stated — mark what isn't

A brief lacks visual detail, so expect more `[CLARIFICATION NEEDED: …]` markers than a design-based run. The skill documents **stated requirements** and never invents features or assumes behavior. Where something is missing, it:

- references an existing, already-documented pattern,
- describes behavior rather than appearance, or
- requests a mockup when the detail is critical.

Unanswered questions are collected under **Pending Questions** in the final report, so nothing silently slips through.
