---
name: figma-to-doc
description: Generate product documentation from Figma design files. Use this when the user provides Figma links, mentions "design files", "mockups", "Figma", or asks to document visual designs.
argument-hint: [figma-url-or-file-key]
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
| 1 | **Fetch Figma comments** | List of comment threads with content (or an explicit "0 comments") | `GET /v1/files/{key}/comments` |
| 2 | **Fetch Dev-Mode annotations** | List of `node id → notes text` read from each node's `annotations` array (or an explicit "0 annotations across N nodes") | `GET /v1/files/{key}/nodes?ids={id}` (OAuth scope `file_content:read`) → read each returned node's **`annotations[]`** (`notes`, `pinned`) |
| 2b | **(Legacy fallback) On-canvas text notes** | Only if the file predates the Dev-Mode Annotations feature: list `type:"TEXT"` nodes used as notes — **clearly marked as design copy, NOT Dev-Mode annotations** | `GET /v1/files/{key}/nodes?ids={id}` → scan `type:"TEXT"` |
| 3 | **Search configured trusted sources** | List of relevant material found (or "none configured") | Browse the trusted sources in `CLAUDE.md` §1 (e.g. Help Center, Blog, live product); skip if none are configured |
| 4 | **Check lesson-learned.md** | Confirm no relevant unresolved issues | Read `.claude/lesson-learned.md` (per Rule 3) |

⛔ **Blocking:** Steps 1, 2, 3, and 4 must all be completed before Phase 2 (2b runs only as a fallback when step 2 yields nothing and the file uses on-canvas text notes).

:::warning Three distinct sources — do not conflate them
- **Comments** = discussion threads on the file (via the comments API). Context for "why" decisions.
- **Annotations (Dev Mode)** = the **`annotations` property on a node** — an array of `{ notes, pinned }` where `notes` carries the annotation text. This is Figma's real Dev-Mode Annotations feature and the **canonical source of business rules.** Read it from the node tree (`GET .../nodes` returns each node's `annotations[]`).
- **TEXT nodes** = ordinary design copy on the canvas. These are **NOT** Dev-Mode annotations; use them only as a clearly-labelled legacy fallback (step 2b).

Comments and annotations are SEPARATE data sources and both MUST be explicitly fetched. **Determine annotations-present yes/no from the `annotations` arrays.** If zero across all fetched nodes, **state that explicitly** in the census below — never silently skip the step (do not assume "no TEXT nodes" means "no annotations").
:::

### Annotation & Comment Census (BLOCKING evidence artifact)

The fetched comments and annotations MUST be recorded in an auditable evidence file so the step cannot be silently skipped and so `lore:doc-validator` can cross-check coverage:

- **Path:** `.claude/sources/figma-{fileKey}-census.md` (one file per Figma file key; re-running the same file overwrites/updates it). This lives under `.claude/`, so the hooks ignore it and it is never reader-facing (Rule 5 safe). Commit it — like `.claude/scenarios/`, it is an auditable source artifact, not a secret. **Never write the Figma token into it.**
- **Format:**

```markdown
# Figma Source Census — {file name}
File key: {key}   URL: {url}   Captured: {YYYY-MM-DD}

## Counts
- Comment threads: N
- Dev-Mode annotations (annotations property): M
- Legacy TEXT-node notes (fallback): K   (used? yes/no)

## Comments (raw)
- [c1] frame/node {id} — "{verbatim comment text}"

## Annotations (raw)
- [a1] node {id} — notes: "{verbatim annotation text}"   pinned: {true|false}

## Coverage map   (only when N + M > 0)
| source ref | business rule extracted | doc file → section reflecting it |
|------------|-------------------------|----------------------------------|
| a1 | Max 6GB upload for premium | docs/upload/index.md → Business Rules |
| c3 | (context only — no rule) | n/a — rationale captured in Overview |
```

- **Timing:** write the Counts + raw lists **before** Phase 2 writing begins; fill the **Coverage map** column **after** the docs are written (every annotation/comment that yields a business rule maps to the doc file+section reflecting it; pure-context comments map to "n/a — context").
- **Zero case:** if there are no comments and no annotations, the census still MUST exist and state `0 comments / 0 annotations — confirmed none present`. That file is the auditable proof the step ran.
- **Re-runs are cheap:** on a later run of the same file key, read the existing census first and re-fetch only changed frames.

### Phase 2: Figma Content Review

| # | Step | How to Verify |
|---|------|---------------|
| 5 | **Navigate all frames** | Frame inventory with IDs and names |
| 6 | **Identify [ignore] pages** | List of skipped pages (or "none") — any page whose name starts with `[ignore]` is out of scope |
| 7 | **Extract images (individual FRAMEs only)** | Downloaded PNGs at 2x, one per frame (see §3) |
| 8 | **Summarize findings** | Business rules distilled from annotations + comments, recorded in the census (Counts + raw lists) before any writing |

⛔ **Blocking:** Do NOT start writing until Phase 2 is complete and the census Counts + raw lists exist.

### Phase 3: Post-Completion Cleanup

| # | Step | How to Verify |
|---|------|---------------|
| 9 | **Delete temporary/composite files** | No unreferenced images under `static/img/` |
| 10 | **Update lesson-learned.md** | New entries added for any issues encountered (Rule 3) |
| 11 | **Propagate lessons to skill files** | Relevant skill file updated, not just lesson-learned.md (Rule 3) |
| 12 | **Run build** | `npm run build` passes with zero errors (only if Docusaurus is installed) |

---

## 3. Core Workflow (Figma-specific)

### Credentials (Figma API)

The Figma REST calls need a token. Read it from the **`FIGMA_TOKEN` environment variable** (sent as the `X-Figma-Token` header), or use a connected Figma MCP server if one is available. **Never** ask the user to paste the raw token into the chat, never echo it in a command you print, and never write it to any file (including `lesson-learned.md` or the final report). If `FIGMA_TOKEN` is unset and no Figma MCP server is connected, stop and ask the user to `export FIGMA_TOKEN=...` (or connect the MCP server) before continuing.

> **Heavy extraction (large files):** the main agent may delegate steps 1–8 of the Pre-Flight to the `lore:figma-extractor` subagent (Task tool) to keep the main context clean. It returns a compact summary (the census payload — counts + raw comments/annotations + provenance refs — plus frame inventory, image list, and open questions). The main agent then **writes the census file** (the subagent returns data; it does not own the artifact). Writing prose and asking the user clarification questions stay in the main context — the subagent is autonomous and cannot ask questions.

### Fetching efficiently (scope the node calls)

Always pass explicit `ids=` for the frames/sections you actually need — never walk the whole file. Use `depth` deliberately: `depth=1` to discover a section's child frames, then a targeted `ids=` call for content. The same `GET /v1/files/{key}/nodes?ids=…` call returns each node's `annotations[]` (step 2) **and** its children for image export — so one scoped fetch serves both annotation reading and frame discovery. Smaller payloads mean fewer timeouts and faster runs.

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
3. Use `depth=1` to discover child frames: `GET /v1/files/{key}/nodes?ids={section_id}&depth=1` — reuse the inventory from Phase 2 step 5 rather than re-fetching.
4. Export a **batch** of frames in one call: `GET /v1/images/{key}?ids={id1},{id2},…&format=png&scale=2` (the images endpoint accepts comma-separated ids and returns a URL map), then download the returned URLs concurrently.
5. Keep batches to ~5 ids to avoid Figma render timeouts.

**Verification:** Inspect the first few images to confirm they show a single UI state (not a composite).

### Where to Store Extracted Images

Store extracted frames under `static/img/{section}/`, mirroring the documentation hierarchy. Use descriptive, hierarchy-based names: `{feature}-{state}-{variant}.png` (e.g. `upload-form-initial.png`, `upload-validation-error.png`, `dashboard-newcomer-view.png`).

> The image storage/reference path rule (`static/img/` on disk, `/img/` in markdown, never `/docs/`) is global — see `CLAUDE.md` Section 6 + Rule 1. Do not restate it; just follow it.

### Mapping Figma to Documentation

| Figma Element | Maps To | Example |
|---------------|---------|---------|
| **Page title** | Document section heading | "Dashboard Overview" → `docs/overview/index.md` |
| **Frame groups** | User scenarios | Frames of an upload flow → "Scenario: Upload Video" |
| **Annotations (Dev Mode, `annotations[]`)** | Business rules OR step descriptions | A node annotation `notes: "Max 6GB for premium"` → Business rule |
| **TEXT nodes (design copy, fallback)** | Treat as design copy, not a business rule, unless used as on-canvas notes | Headline/body copy → page content; an on-canvas note → fallback business rule |
| **Comments** | Context for "why" decisions | Comment explaining rationale → Overview section |
| **Component variants** | User role differences | Button states per user type → role-based behavior |
| **Empty states** | Edge case documentation | Empty list frame → empty state scenario |

> **Large sections:** once the frame inventory and scenario count are known, if a Figma page maps to a section that will exceed the §2 split threshold (many frame-groups → many scenarios), split it into an overview `index.md` + sibling sub-pages per the `CLAUDE.md` §2 split rule. Decide this before writing.

### Handling Figma Edge Cases

- **Missing information:** Document what IS shown; mark gaps as `[CLARIFICATION NEEDED: ...]`; ask the user.
- **Lorem Ipsum / placeholder text:** Ask for real content; if unavailable insert a placeholder **in the project's documentation language** (§7) — e.g. English: `[real content pending content-team approval]`, Persian: `[محتوای واقعی در انتظار تایید تیم محتوا]` — then flag it in the final report.
- **Conflicting annotation vs comment:** Prefer the annotation (usually closer to current design); ask the user to confirm; note in final report.
- **Multiple design versions:** Ask which to document; if the latest is clear, document it and note "Documented version X (most recent as of [date])".

---

## 4. DoD Additions (Figma-specific deltas only)

- **Inline image placement:** Each exported frame image must appear inline at the exact scenario step it illustrates. The full rule and the canonical correct/incorrect example live in `CLAUDE.md` Section 4 — follow it; do not group images at the end.
- All other scenario, accuracy, and technical-validity rules are global — see `CLAUDE.md` §4–§6.

---

## 5. Final Report Additions (Figma-specific fields)

The base final-report structure is defined in `CLAUDE.md` Section 8. In addition, a Figma-sourced report MUST include:

- **Figma sources:** file name + URL, pages reviewed, pages skipped (`[ignore]`), and the census counts — **Dev-Mode annotations** (from the `annotations` property) and comment threads reviewed, plus legacy TEXT-node notes if the fallback was used. The full census (raw lists + coverage map) is persisted at `.claude/sources/figma-{key}-census.md`.
- **Images extracted:** count and storage directories (`static/img/{section}/`), with dimensions/scale.

---

## 6. Completion Checklist

**Mandatory self-verification (before delivery):** run the `lore:doc-validator` subagent (Task tool) on the produced document(s). If it reports any BLOCKING failure (§0/§1/§4/§6/§8, Rule 3, Rule 4), fix and re-run until it returns green. Only then write the final report (§8). This does not duplicate the DoD — it invokes the canonical validator.

- [ ] `lore:doc-validator` run and returned APPROVED (no blocking failures)
- [ ] All Figma frames reviewed (except `[ignore]` pages)
- [ ] Dev-Mode annotations (the `annotations` property) AND comments read and incorporated; TEXT-node fallback noted if used
- [ ] Annotation & Comment Census written to `.claude/sources/figma-{key}-census.md` (counts + raw lists + coverage map; zero-case states "confirmed none present")
- [ ] Images exported as individual FRAMEs at 2x, stored under `static/img/{section}/`
- [ ] Images placed inline at correct scenario steps (per `CLAUDE.md` §4)
- [ ] Temporary/composite files cleaned up
- [ ] Final report includes Figma file details + extracted-image list
- [ ] All BLOCKING rules from the global DoD satisfied

---

## 7. Reference Example

See [examples/overview-from-figma.md](examples/overview-from-figma.md) for a complete example of documentation generated from Figma designs.
