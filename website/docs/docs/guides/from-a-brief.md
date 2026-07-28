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

1. **Reads the brief end to end** and extracts every user story and acceptance criterion, identifying gaps and ambiguities up front. It also **actually fetches** your configured trusted sources and searches them for material about the features in scope, recording each source's findings in an auditable source census — every row carrying the [receipt](../concepts/definition-of-done.md#evidence-not-attestation) behind it, so a source that was never opened cannot be written up as "nothing relevant". Anything you asked for in conversation is written down as a numbered row before reading starts, and the run cannot be delivered while one is still open.
2. **Asks clarifying questions** where behavior, rules, edge cases, or exact messages are unspecified — capped at a handful of high-impact questions, with the rest becoming explicit placeholders rather than an unanswerable wall of questions.
3. **Infers scenarios** from user stories — turning *"As a [role], I want [action], so that [benefit]"* into a complete scenario with purpose, preconditions, flow, and postconditions. Gherkin criteria map structurally: *Given* → preconditions, *When*/*Then* → a flow step and its system reaction, failure outcomes → extensions.
4. **Walks the edge-case taxonomy** — every scenario is checked against the documentation template's edge-case categories (empty states, boundaries, concurrency, …); a category the brief doesn't address becomes a targeted question or an explicit placeholder, never an invented flow.
5. **Converts acceptance criteria into explicit business rules**, making vague language specific. A subjective criterion — "fast", "good UX" — is never silently accepted as a rule; it is flagged with a suggested measurable formulation.
6. **Validates and reports**, including a log of every clarification raised.

## It tells you when a brief isn't ready

If the brief is missing its essentials — acceptance criteria, personas/roles, or out-of-scope statements — the skill says so before writing, warns that the output will be placeholder-heavy in those areas, and proceeds only with your explicit go-ahead. It never silently generates a document from an unready brief.

## Document what's stated — mark what isn't

A brief lacks visual detail, so expect more `[CLARIFICATION NEEDED: …]` markers than a design-based run. The skill documents **stated requirements** and never invents features or assumes behavior. Where something is missing, it:

- references an existing, already-documented pattern,
- describes behavior rather than appearance, or
- requests a mockup when the detail is critical.

Unanswered questions are collected under **Pending Questions** in the final report, so nothing silently slips through.
