---
name: doc-reviewer
description: Validate existing documentation against the Definition of Done. Use this to review docs before delivery, audit existing files, or when the user asks to "review", "validate", "check", or "audit" documentation.
argument-hint: [doc-path]
user-invocable: true
---

# Documentation Reviewer Skill

**This skill provides systematic validation of documentation against the Definition of Done. It complements (does not override) the global system prompt in `.claude/CLAUDE.md`.**

> **GOLDEN RULE (Rule 4 — Single Place of Truth):** This skill does NOT restate the DoD rules — the DoD is canonical in `CLAUDE.md`. This skill provides the *review method, checklist, and report format* only, and references each rule by its Section number.

You are auditing product documentation to ensure it meets the global Definition of Done. The DoD itself lives in `CLAUDE.md` (always in context); this skill tells you how to validate against it.

---

## 1. When to Use

- The user asks to "review", "validate", "audit", "check", or "verify" documentation.
- Before delivering any documentation (internal auto-validation per `CLAUDE.md` Auto-Validation Rule).

---

## 2. Pre-Flight Checklist

- Load the complete Definition of Done from `CLAUDE.md` (Sections 0–8 + Rule 3 + Rule 4 + Rule 5). Do not copy it here — read it from the source.
- Identify the document(s) under review and their expected place in the structure.

---

## 3. Core Workflow — 4-Step Review

### Step 1 — Referential Validation Checklist

Validate each item against the **canonical rule in `CLAUDE.md`** (do not re-derive the rule; just check compliance). Blocking sections are marked ⛔.

| DoD area | What to check (compliance) | Canonical rule |
|----------|----------------------------|----------------|
| ⛔ **§0 Pre-Writing** | Evidence that the available inputs were reviewed; every configured trusted source searched (or "none configured"). **For Figma** (Sources name a Figma file or `.claude/sources/figma-*-census.md` exists): the census MUST exist with explicit counts; if counts > 0, every annotation/comment business rule in its Coverage map MUST resolve to a real doc file+section — a missing census or an uncovered rule is a **blocking** §0 failure | `CLAUDE.md` §0 |
| ⛔ **§1 Trusted Sources** | No fabricated facts or unverified third-party sources; where trusted sources are configured, claims are consistent with them; missing info marked `[CLARIFICATION NEEDED]` | `CLAUDE.md` §1 |
| **§2 Scope & Structure** | Valid frontmatter (sidebar_position, title, description, tags); no `#` (H1) in the body — the page title comes from frontmatter, top-level sections are `##` and scenarios are `###`; the Document Info block and all **required** template sections present with content; **optional** sections (marked `_(Optional — delete …)_`) are either filled or removed — never left empty or carrying the `_(Optional …)_` marker; an oversized page past the §2 split threshold (>6 scenarios or >3000 words) that was not split into an overview + sibling pages is a **warning**, and split pages must be mirrored in `sidebars.ts` and cross-linked | `CLAUDE.md` §2 + template |
| **§3 User Roles** | Relevant roles documented using approved names; role differences explained | `CLAUDE.md` §3 |
| ⛔ **§4 Scenarios** | Each has Purpose/Roles Involved/Preconditions/Main Flow/Extensions/Postconditions; images inline at the right step (not grouped); options, validations, exact messages present; error/validation/empty/edge cases documented as **Extensions** (anchored to their Main Flow step), not omitted or scattered | `CLAUDE.md` §4 + template |
| **§5 Accuracy** | Consistent terminology; UI labels match source; explicit (not vague) rules; KPIs where applicable | `CLAUDE.md` §5 |
| ⛔ **§6 Technical Validity** | Internal links work; image markdown uses `/img/` (not `/static/img/`); files exist under `static/img/`; no images in `/docs/`; no orphan images; `npm run build` passes **if Docusaurus is installed** (otherwise N/A — verify links/images manually) | `CLAUDE.md` §6 |
| **§7 Language & Style** | Content language matches §7; English file/dir names; product-focused (non-marketing) tone | `CLAUDE.md` §7 |
| ⛔ **§8 Final Report** | Final report present with Sources, Tools/Skills, and Summary | `CLAUDE.md` §8 |
| ⛔ **Rule 3 Lessons** | Issues encountered are documented in `lesson-learned.md` (4 fields each); skill-related lessons also propagated to the skill file; no orphan files from error recovery | `CLAUDE.md` Rule 3 |
| ⛔ **Rule 4 Single Truth** | No global rule restated inside skills/docs where a reference should be used; facts live in one canonical place | `CLAUDE.md` Rule 4 |
| ⛔ **Rule 5 Reader-Facing** | No tooling references in `docs/`: no `.claude/` paths, no `CLAUDE.md` citation, no `lore:*` skill/subagent names; config facts (§1/§3) stated directly, not cited | `CLAUDE.md` Rule 5 |

For each item record: ✅ PASS / ⚠️ WARNING / ❌ FAIL, with the specific location of any issue.

### Step 2 — Verify Technical Validity Concretely

For §6, actually run the checks rather than eyeballing:
- Test each internal link resolves.
- Grep image references; confirm each uses `/img/` and the file exists under `static/img/`.
- Confirm no image files live under `docs/`.
- Grep `docs/` for tooling references (Rule 5): `.claude/`, `CLAUDE.md`, and the `lore:` namespace. Any match is a blocking failure.
- **If Docusaurus is installed** (a `package.json` with docusaurus is present): run `npm run build` and confirm zero errors. Otherwise mark the build check **N/A** (docs-only project) and rely on the manual link/image checks above — do not treat the missing build as a failure.

### Step 3 — Generate Review Report

```markdown
# 📋 Documentation Review Report

**Document:** [file path]
**Reviewed on:** [date]
**Overall Status:** [✅ PASS / ⚠️ PASS WITH WARNINGS / ❌ FAIL]

## Section Results
| DoD area | Status | Issue (location) |
|----------|--------|------------------|
| §0 Pre-Writing | ✅/⚠️/❌ | ... |
| §1 Trusted Sources | ✅/⚠️/❌ | ... |
| §2 Scope & Structure | ✅/⚠️/❌ | ... |
| §3 User Roles | ✅/⚠️/❌ | ... |
| §4 Scenarios | ✅/⚠️/❌ | ... |
| §5 Accuracy | ✅/⚠️/❌ | ... |
| §6 Technical Validity | ✅/⚠️/❌ | ... |
| §7 Language & Style | ✅/⚠️/❌ | ... |
| §8 Final Report | ✅/⚠️/❌ | ... |
| Rule 3 Lessons | ✅/⚠️/❌ | ... |
| Rule 4 Single Truth | ✅/⚠️/❌ | ... |
| Rule 5 Reader-Facing | ✅/⚠️/❌ | ... |

## Blocking Failures: [count]
(§0, §1, §4, §6, §8, Rule 3, Rule 4, Rule 5)

## Recommendation
[✅ APPROVED FOR DELIVERY / ⚠️ APPROVED WITH WARNINGS / ❌ BLOCKED — DO NOT DELIVER]

## Required Actions (if blocked)
1. **[area] issue** — Location: [line/section] — Fix: [specific fix]
```

### Step 4 — Block or Approve

- **Any blocking failure (⛔ items)** → ❌ **DO NOT DELIVER.** Present the report, name the failed blocking areas, give specific fix instructions, and offer to fix.
- **No blocking failures** → ✅ **APPROVE.** Present the report and note any non-blocking warnings as future improvements.

### Fixing Common Issues (reference)

- **Wrong markdown image path** — `![img](/static/img/section/feature.png)` ❌ → `![img](/img/section/feature.png)` ✅ (physical storage stays `static/img/`).
- **Image in `/docs/`** — move the file to `static/img/section/` and reference it as `/img/section/...`.
- **Images grouped at end of scenario** — move each image inline to the step it illustrates (per `CLAUDE.md` §4).
- **Broken internal link** — find the correct file path and update the link.
- **Missing final report** — add the report per `CLAUDE.md` §8 (Sources / Tools / Summary).

---

## 4. DoD Additions

This skill itself adds no new documentation rules. It enforces the existing global DoD plus Rule 3 (lessons propagated) and Rule 4 (no duplicated facts) as explicit review gates.

---

## 5. Output

The deliverable of this skill is the **Review Report** above (not product documentation). When the report blocks delivery, the reviewed document must not be delivered until the listed blocking failures are fixed.

---

## 6. Completion Checklist

- [ ] All DoD areas checked against their canonical `CLAUDE.md` Section (Step 1)
- [ ] §6 technical checks actually run, including `npm run build` if Docusaurus is installed (Step 2)
- [ ] All blocking areas explicitly validated (§0, §1, §4, §6, §8, Rule 3, Rule 4, Rule 5)
- [ ] Figma census cross-checked when input was Figma (§0); oversized pages flagged per the §2 split rule
- [ ] Review report generated with per-area status and locations
- [ ] Clear recommendation (approve / warnings / blocked) with required actions

---

## 7. Reference Example

See [examples/review-report.md](examples/review-report.md) for a complete example of a documentation review report with issues found and fixes required.
