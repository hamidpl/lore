<!--
  Lore methodology rules — DO NOT EDIT.
  This file is MANAGED BY THE LORE PLUGIN and is overwritten automatically on plugin
  update (a SessionStart hook keeps it in sync). Any manual change here will be lost.
  Product-specific settings (trusted sources §1, user roles §3, product overview,
  documentation structure) live in CLAUDE.md, which imports this file. Add your own
  custom project rules to CLAUDE.md, never here.
-->

# Lore Documentation Methodology

These are the always-on documentation rules (General Rules + the Definition of Done). They are product-agnostic and maintained in the Lore plugin, so improvements reach every project on `/plugin update`. `CLAUDE.md` imports this file and adds the product-specific layer.

---

## General Documentation Rules

### Rule 1: Image Storage (BLOCKING)

Every image used in documentation—whether extracted from Figma, captured from live site, or obtained elsewhere—must be stored exclusively under `/static/img/`, following a directory structure aligned with the documentation hierarchy.

**⛔ BLOCKING: Images must NEVER be placed inside `/docs/` or any other directory.**

The physical-storage vs. markdown-reference path convention (and why) lives in §6 — follow it there.

### Rule 2: Post-Completion Updates

After completing documentation for any new section, update `README.md` and `docs/intro.md` so the site stays navigable and current.

### Rule 3: Persistent Lessons Learned (BLOCKING)

Whenever an error, issue, inconsistency, or misconfiguration occurs during any task:

1. **Pre-check:** Before proposing a solution, you MUST check `.claude/lesson-learned.md`. If a relevant entry exists, apply its documented solution immediately — do not ask the user or propose alternatives.
2. **Document new issues:** If the issue is not documented, after resolving it append an entry to `.claude/lesson-learned.md` with four fields: **Problem**, **Root Cause**, **Solution**, **Preventive Rule or Pattern**, plus a Date.
3. **Repeated issues:** If a documented issue recurs, reference the existing entry, explain why it didn't prevent the recurrence, and update the entry.

- ⛔ This rule is BLOCKING and must not be overridden or weakened by any skill.
- ✅ Treat `lesson-learned.md` as a living knowledge base, not a log file.

### Rule 4: Single Place of Truth (BLOCKING)

Every fact, rule, or definition must be written in **exactly one canonical location**. Anywhere else that needs it must **reference** it — never **restate** it.

**Canonical locations:**

| Fact category | Canonical location |
|---------------|--------------------|
| Methodology: General Rules / DoD / image paths | `.claude/lore-methodology.md` (this file — plugin-owned, do not edit) |
| Product layer: trusted sources / user roles / product overview / documentation structure | `.claude/CLAUDE.md` |
| Input-specific workflow logic | the relevant skill in the **Lore** plugin (`lore:{name}`) |
| Lessons learned | `.claude/lesson-learned.md` |
| Document structure template | `templates/product-document-template.md` |
| Skill structure template | `templates/skill-template.md` in the **Lore** plugin |

- ⛔ Copying the full text of an existing rule into a second place is prohibited. This rule is BLOCKING.

**Carve-out for Rule 3:** `lesson-learned.md` is *reactive* (a lookup index) and a skill file is *proactive* (an execution rule). The full lesson text stays canonical in `lesson-learned.md`; a skill carries only a short operational rule + a reference.

### Rule 5: Reader-Facing Output (BLOCKING)

Everything under `docs/` is written for the product's readers. It must **never** mention the authoring tooling: no reference to Claude/Anthropic, to the Lore plugin or its skills/subagents (`lore:*`), to the Playwright/browser automation, or to any internal authoring artifact or path under `.claude/` (`CLAUDE.md`, this methodology file, scenario scripts, observed-issues, `lesson-learned.md`, settings).

When a published doc needs a fact that lives in a config section (e.g. trusted sources §1, user roles §3), **state the fact itself** — do not cite the section number or the `.claude/` path. Example: write "All users see the same behavior", not "no roles configured (see §3)".

- ⛔ This rule is BLOCKING. A reader-facing reference to the tooling means the document is NOT done.
- ℹ️ Boundary with Rule 4: Rule 4 governs how the *authoring/config* files (`CLAUDE.md`, this methodology file, skills) reference one another by path/section. Rule 5 governs the *reader-facing output* under `docs/`, which is self-contained and tool-agnostic. The in-chat Final Report (§8) is a process deliverable, not reader-facing output — it may still name the skill/subagents.

---

## Definition of Done (DoD)

> **⚠️ Violation of any Blocking section means the work is NOT DONE.**
>
> The DoD spans this file and `CLAUDE.md`: §0, §2, §4–§8 (methodology) live here; **§1 Trusted Sources and §3 User Roles are product-layer sections defined in `CLAUDE.md`.** Section numbers are unique across both files, so a reference to any "§N" resolves regardless of which file it lives in.

### Section 0 — Exhaust Every Source (Pre-Writing) (Blocking)

**Before documenting any page/screen/feature, read EVERY source that could describe it, and extract everything relevant to that page.** Richer, more accurate documentation comes from using *all* the information that exists — not a convenient subset. This is the single general rule that governs source-gathering; the concrete "what to read" list is the input-specific **source manifest** each skill carries.

- ✅ **The source set to exhaust** = every configured trusted source in §1 **+** all materials/artifacts the user provided **+** the input-specific source manifest listed in the active skill's Pre-Flight (the skill owns that list).
- ✅ Actively extract and analyze information from those sources **before** writing — for each page, pull whatever the sources say about it.
- ⛔ **Reading only a subset of the available sources is a blocking failure.** Writing or editing before reviewing the sources you DO have is strictly prohibited.
- ✅ **State absence explicitly.** When a source type in scope yields nothing (e.g. no annotations, no comments, no relevant trusted-source material), record that explicitly ("0 … — confirmed none") — never silently skip a source.
- ℹ️ If no specific trusted sources are configured yet, this does not block you — proceed from the materials the user provided (see §1).

| Input Type | Skill to Use | Sources to Exhaust |
|------------|--------------|--------------------|
| **Figma designs** | `lore:figma-to-doc` | Figma file + everything the figma-to-doc source manifest lists (comments, Dev-Mode annotations, prototype flows/interactions, component variants, variables, frames) |
| **Briefs/Epics** | `lore:brief-to-doc` | Product briefs, PRDs, user stories, acceptance criteria |
| **Live Product** | `lore:site-to-doc` | Live site via browser automation, scenario scripts, screenshots |
| **All types** | - | Configured trusted sources (§1) + user clarifications |

> The active skill's Pre-Flight source manifest is the authoritative "what to read" for its input type. For Figma, a source-census evidence artifact under `.claude/sources/` is mandatory (the Figma skill defines its format) — delivering without it, or leaving any manifest source unread, is a §0 failure.
>
> **Adding a new must-read source:** if it applies to *every* input type, add it here (§0); if it is specific to one input type, add it to that skill's Pre-Flight source manifest. Keep the rule here general and the list in the skill.

### Section 1 — Trusted Sources — PRODUCT LAYER

> Defined in `CLAUDE.md` §1 (product layer). The rule to treat configured sources as authoritative and never fabricate facts lives there; the obligation to **read all of them** for the page being documented is §0 above.

### Section 2 — Documentation Scope & Structure

Every document follows the structure defined in the canonical template at `templates/product-document-template.md` — use its sections, in its order. If the project's template is customized, that file remains the single source of truth for document structure (Rule 4).

Independent of the template body, every document must begin with valid YAML frontmatter (enforced by the frontmatter hook and §6):

**Frontmatter Format:**
```yaml
---
sidebar_position: 1
title: [title in the documentation language]
description: [Short description]
tags: [section-name, feature-name]
---
```

**Multi-Page Sections (split rule).** A single page that grows too large stops being readable. **Split a section when its `index.md` would exceed more than 6 documented scenarios OR more than 3000 words — whichever comes first.** When that happens:

- Convert `docs/{section}/index.md` into an **overview / hub page** (`sidebar_position: 1`): keep the Introduction & Purpose, Scope, and a consolidated Business-Rules overview, plus a linked list of the sub-pages with a one-line description of each.
- Move each cohesive cluster (e.g. one group of scenarios) into a **sibling sub-page** `docs/{section}/{sub-topic}.md`, each with its own frontmatter (`sidebar_position: 2, 3, …`, own `title`/`description`/`tags`).
- **Stay cohesive, not fragmented:** the index links every child; each child links back to the index; related siblings cross-link where their flows connect.
- Images stay under `static/img/{section}/` (§6). Mirror the split in `sidebars.ts`: the section becomes a `category` with `index` first, then the siblings.

This threshold is the single source of truth; reviewers and the validator reference "§2 split rule" rather than restating the number. An oversized page that was **not** split is a **warning** (not blocking) — over-splitting is also a failure, so use judgement.

### Section 3 — User Roles — PRODUCT LAYER

> Defined in `CLAUDE.md` §3 (product layer). Where a feature behaves differently by role, document every relevant role using the product's approved names (never invent names); if behavior is identical for all roles, state that explicitly in plain product language (never by citing the section number or `.claude/` path — Rule 5). The approved role names live in `CLAUDE.md` §3.

### Section 4 — Scenario Writing Rules (Blocking)

Scenarios must be complete, step-by-step, and written from the user's perspective. Each must include **Purpose**, **Roles Involved**, **Preconditions**, **Main Flow** (steps with system reactions), **Extensions** (alternative & exception flows), and **Postconditions** — following the scenario structure in `templates/product-document-template.md`. Each scenario is its own `###` sub-heading under a single `## Scenarios` section, **numbered in order** (the exact heading format — `Scenario N: [goal]` — is defined in the template; do not restate it here, Rule 4). The page title/H1 comes from frontmatter — the body carries no `#` heading.

**Errors, validation failures, empty states, and edge cases belong in the scenario's Extensions section** — anchored to the Main Flow step they depart from (step-letter numbering: `3a`, `3a1`, …), not scattered through the happy-path steps and not omitted. The template defines the exact format; do not restate it here (Rule 4).

**Images must** be placed inline at the correct scenario step, directly matching that step, appearing between steps.

**⛔ BLOCKING:** Images grouped at the end of a scenario or in a separate "Images" section is NOT acceptable.

Mandatory scenario details: all user options, all form fields (required vs optional), all validation rules, all system messages (success and error, exact wording), and edge cases — checked against the edge-case coverage taxonomy in `templates/product-document-template.md` (Scenarios section) and documented as Extensions.

### Section 5 — Accuracy & Consistency

Terminology must match existing docs; UI labels and behaviors must exactly match the source; business rules, constraints, limits, and validations must be explicit and specific (not vague); KPIs documented where applicable.

### Section 6 — Technical Validity (Blocking)

- All internal links and anchors work
- All images stored in `static/img/{section}/` (physical location)
- All markdown image references use `/img/{section}/` (NOT `/static/img/`)
- **Responsive screenshots (path convention):** mobile-view screenshots go under `static/img/{section}/mobile/` (referenced `/img/{section}/mobile/…`) and tablet-view under `static/img/{section}/tablet/`. The `/mobile/` path segment is meaningful: the Docusaurus stylesheet renders any `/mobile/` image at **half width on desktop, full width on small screens** — so a tall portrait phone shot doesn't dominate the page. Tablet (and desktop) images display full width.
- **⛔ BLOCKING: mobile-view screenshots must be embedded with a raw HTML tag** — `<img src="/img/{section}/mobile/…" alt="…" />` (self-closing, MDX requires the `/>`), never markdown `![…](…)` syntax. Docusaurus rewrites markdown-embedded images to hashed `/assets/images/…` URLs at build time, which strips the `/mobile/` segment the half-width styling keys on; a raw `<img>` keeps its `src` verbatim. Desktop and tablet images keep normal markdown syntax.
- **⛔ BLOCKING:** No images in `/docs/`
- **⛔ BLOCKING:** No tooling/internal references in reader-facing docs (Rule 5) — no `lore:*`, no `.claude/` paths, no `CLAUDE.md` citation
- Documentation builds in Docusaurus with no errors
- Sidebar placement reflects product hierarchy; frontmatter YAML valid

| Aspect | Correct |
|--------|---------|
| Physical storage | `static/img/overview/feature.png` |
| Markdown reference | `![description](/img/overview/feature.png)` |
| Mobile-view screenshot | `static/img/overview/mobile/feature.png` → `<img src="/img/overview/mobile/feature.png" alt="…" />` (raw tag — auto half-width on desktop) |
| Why not `/static/` | Docusaurus serves `static/` at root; `/static/img/` causes "file not found" |

### Section 7 — Language & Style

| Item | Rule |
|------|------|
| Content language | the documentation language configured in the product layer (`CLAUDE.md`) |
| File names | English (lowercase, hyphens) |
| Directory names | English (lowercase, hyphens) |
| Writing style | Product-oriented, business-focused, non-marketing |

### Section 8 — Mandatory Final Report (Blocking)

At the end of every task, provide a final report with: **(1) Sources Used** (primary input, artifacts reviewed, images extracted + locations, referenced trusted sources, user clarifications); **(2) Tools and Skills Used** (skill invoked, files read/modified, URLs, validation tools); **(3) Summary** (what was added/updated with paths, what was excluded and why, what remains unknown, blocking issues and resolutions).

⛔ **BLOCKING:** If the final report is missing or incomplete, the documentation is NOT complete.

### Auto-Validation Rule

Before delivering, validate against this DoD. If any blocking section (0, 1, 4, 6, 8) fails, do NOT deliver — report which section failed, why, and what's required. For §0/§1, "fails" means writing without reviewing the available inputs, leaving a source in scope unread (any source from the active skill's manifest, or a configured trusted source not searched for the pages documented), or fabricating facts / using unverified third-party sources — not the mere absence of configured trusted sources. When uncertain, use `lore:doc-reviewer` for systematic validation.

---

## Input-Specific Workflows

| Input Source | Skill to Use |
|--------------|--------------|
| **Figma designs** | `lore:figma-to-doc` |
| **Briefs/Epics** | `lore:brief-to-doc` |
| **Live Product** | `lore:site-to-doc` |
| **Review/Audit** | `lore:doc-reviewer` |

All skills are provided by the **Lore** plugin (`lore:{name}`); see the Prerequisite section in `CLAUDE.md`. Skills complement this system prompt — they add input-specific logic without overriding these global rules.

### Automation Layer (Subagents + Hooks)

Both are bundled in the **Lore** plugin, so they apply to every repo that installs it:

- **`lore:doc-validator` subagent** — a read-only validator that audits a document against this DoD and returns a pass/fail report. Producer skills MUST run it at completion before delivery (self-verification). It applies the method in the `lore:doc-reviewer` skill; it does not restate rules (Rule 4).
- **Hooks** (bundled in the Lore plugin's `hooks/hooks.json`, via `${CLAUDE_PLUGIN_ROOT}`) — deterministic enforcement + upkeep: `PostToolUse` hooks block (exit 2) any `docs/` markdown using `/static/img/` or any image written under `docs/`; a `Stop` hook warns about orphan images; a `SessionStart` hook keeps this methodology file in sync with the installed plugin version (silent copy + a one-line notice when it updates).
