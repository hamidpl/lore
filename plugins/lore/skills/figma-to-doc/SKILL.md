---
name: figma-to-doc
description: Generate product documentation from Figma design files. Use this when the user provides Figma links, mentions "design files", "mockups", "Figma", or asks to document visual designs.
user-invocable: true
---

# Figma to Documentation Skill

**This skill provides input-specific instructions for documenting from Figma designs. It complements (does not override) the global system prompt in `.claude/CLAUDE.md`.**

> **GOLDEN RULE (Rule 4 — Single Place of Truth):** This skill contains ONLY Figma-specific content. It does NOT restate global rules (DoD, image paths, user roles, trusted sources, final-report structure) — it references the relevant Section in `CLAUDE.md`.

You are extracting product documentation from Figma design files. Approved sources, user roles, image-path rules, and the document structure are defined globally in `CLAUDE.md` — this skill only adds what is unique to Figma.

---

## 1. When to Use

- The user provides a Figma link, or mentions "design file", "mockup", "wireframe", "Figma".
- The primary source for the documentation is a visual design (not a brief or the live site).

---

## 2. Pre-Flight Checklist (BLOCKING)

Complete IN ORDER before writing. This is the Figma-specific expansion of `CLAUDE.md` Section 0 (Pre-Writing) and Section 1 (Trusted Sources) — see those sections for the global requirement.

### Phase 1: Source Collection

| # | Step | How to Verify | API/Method |
|---|------|---------------|------------|
| 1 | **Fetch Figma comments** | List of comment threads with content | `GET /v1/files/{key}/comments` |
| 2 | **Fetch Figma annotations** | List of TEXT nodes extracted from node tree | `GET /v1/files/{key}/nodes?ids={id}` → scan for `type: "TEXT"` |
| 3 | **Search configured trusted sources** | List of relevant material found (or "none configured") | Browse the trusted sources in `CLAUDE.md` §1 (e.g. Help Center, Blog, live product); skip if none are configured |
| 4 | **Check lesson-learned.md** | Confirm no relevant unresolved issues | Read `.claude/lesson-learned.md` (per Rule 3) |

⛔ **Blocking:** ALL 5 steps must be completed before Phase 2.

:::warning Comments ≠ Annotations
- **Comments** = discussion threads (via comments API)
- **Annotations** = TEXT nodes on the design canvas (via node tree API)
- These are TWO SEPARATE data sources. Both MUST be explicitly fetched and reviewed.
:::

### Phase 2: Figma Content Review

| # | Step | How to Verify |
|---|------|---------------|
| 6 | **Navigate all frames** | Frame inventory with IDs and names |
| 7 | **Identify [ignore] pages** | List of skipped pages (or "none") — any page whose name starts with `[ignore]` is out of scope |
| 8 | **Extract images (individual FRAMEs only)** | Downloaded PNGs at 2x, one per frame (see §3) |
| 9 | **Summarize findings** | Written summary of business rules from annotations + comments |

⛔ **Blocking:** Do NOT start writing until Phase 2 is complete.

### Phase 3: Post-Completion Cleanup

| # | Step | How to Verify |
|---|------|---------------|
| 10 | **Delete temporary/composite files** | No unreferenced images under `static/img/` |
| 11 | **Update lesson-learned.md** | New entries added for any issues encountered (Rule 3) |
| 12 | **Propagate lessons to skill files** | Relevant skill file updated, not just lesson-learned.md (Rule 3) |
| 13 | **Run build** | `npm run build` passes with zero errors |

---

## 3. Core Workflow (Figma-specific)

> **Heavy extraction (large files):** the main agent may delegate steps 1–8 of the Pre-Flight to the `lore:figma-extractor` subagent (Task tool) to keep the main context clean. It returns a compact summary (business rules + frame inventory + image list + open questions). Writing prose and asking the user clarification questions stay in the main context — the subagent is autonomous and cannot ask questions.

### Image Extraction

Extract images for: initial UI states, each significant state change, error/validation states, success confirmations, and role-specific views. Export at **2x** resolution; PNG for UI, JPG for photos.

#### ⛔ CRITICAL: Section vs Frame Export (Blocking)

When using the Figma REST API to export images:

- **NEVER export SECTION nodes** — Sections are containers holding multiple frames; exporting one produces a single composite image with all child frames side-by-side, unsuitable for inline docs.
- **ALWAYS export individual FRAME nodes** — Each frame is a single UI state → a clean, single image.

**Workflow:**
1. Fetch the node tree: `GET /v1/files/{key}/nodes?ids={node_id}&depth=2`
2. Check node type:
   - `type: "SECTION"` → get children, extract individual `FRAME` IDs
   - `type: "FRAME"` → export directly
3. Use `depth=1` to discover child frames: `GET /v1/files/{key}/nodes?ids={section_id}&depth=1`
4. Export each frame: `GET /v1/images/{key}?ids={frame_id}&format=png&scale=2`
5. Batch exports in groups of ~5 to avoid Figma render timeouts.

**Verification:** Inspect the first few images to confirm they show a single UI state (not a composite).

### Where to Store Extracted Images

Store extracted frames under `static/img/{section}/`, mirroring the documentation hierarchy. Use descriptive, hierarchy-based names: `{feature}-{state}-{variant}.png` (e.g. `upload-form-initial.png`, `upload-validation-error.png`, `dashboard-newcomer-view.png`).

> The image storage/reference path rule (`static/img/` on disk, `/img/` in markdown, never `/docs/`) is global — see `CLAUDE.md` Section 6 + Rule 1. Do not restate it; just follow it.

### Mapping Figma to Documentation

| Figma Element | Maps To | Example |
|---------------|---------|---------|
| **Page title** | Document section heading | "Dashboard Overview" → `docs/overview/index.md` |
| **Frame groups** | User scenarios | Frames of an upload flow → "Scenario: Upload Video" |
| **Annotations** | Business rules OR step descriptions | "Max 6GB for premium" → Business rule |
| **Comments** | Context for "why" decisions | Comment explaining rationale → Overview section |
| **Component variants** | User role differences | Button states per user type → role-based behavior |
| **Empty states** | Edge case documentation | Empty list frame → empty state scenario |

### Handling Figma Edge Cases

- **Missing information:** Document what IS shown; mark gaps as `[CLARIFICATION NEEDED: ...]`; ask the user.
- **Lorem Ipsum / placeholder text:** Ask for real content; if unavailable use `[محتوای واقعی در انتظار تایید تیم محتوا]`; flag in final report.
- **Conflicting annotation vs comment:** Prefer the annotation (usually closer to current design); ask the user to confirm; note in final report.
- **Multiple design versions:** Ask which to document; if the latest is clear, document it and note "Documented version X (most recent as of [date])".

---

## 4. DoD Additions (Figma-specific deltas only)

- **Inline image placement:** Each exported frame image must appear inline at the exact scenario step it illustrates. The full rule and the canonical correct/incorrect example live in `CLAUDE.md` Section 4 — follow it; do not group images at the end.
- All other scenario, accuracy, and technical-validity rules are global — see `CLAUDE.md` §4–§6.

---

## 5. Final Report Additions (Figma-specific fields)

The base final-report structure is defined in `CLAUDE.md` Section 8. In addition, a Figma-sourced report MUST include:

- **Figma sources:** file name + URL, pages reviewed, pages skipped (`[ignore]`), count of annotations and comments reviewed.
- **Images extracted:** count and storage directories (`static/img/{section}/`), with dimensions/scale.

---

## 6. Completion Checklist

**Mandatory self-verification (before delivery):** run the `lore:doc-reviewer` subagent (Task tool) on the produced document(s). If it reports any BLOCKING failure (§0/§1/§4/§6/§8, Rule 3, Rule 4), fix and re-run until it returns green. Only then write the final report (§8). This does not duplicate the DoD — it invokes the canonical validator.

- [ ] `lore:doc-reviewer` run and returned APPROVED (no blocking failures)
- [ ] All Figma frames reviewed (except `[ignore]` pages)
- [ ] Both annotations AND comments read and incorporated
- [ ] Images exported as individual FRAMEs at 2x, stored under `static/img/{section}/`
- [ ] Images placed inline at correct scenario steps (per `CLAUDE.md` §4)
- [ ] Temporary/composite files cleaned up
- [ ] Final report includes Figma file details + extracted-image list
- [ ] All BLOCKING rules from the global DoD satisfied

---

## 7. Reference Example

See [examples/overview-from-figma.md](examples/overview-from-figma.md) for a complete example of documentation generated from Figma designs.
