---
name: brief-to-doc
description: Generate product documentation from product briefs, epics, PRDs, or user stories. Use this when the user provides written requirements, feature descriptions, or textual specifications without visual designs.
user-invocable: true
---

# Brief to Documentation Skill

**This skill provides input-specific instructions for documenting from briefs and written specifications. It complements (does not override) the global system prompt in `.claude/CLAUDE.md`.**

> **GOLDEN RULE (Rule 4 — Single Place of Truth):** This skill contains ONLY brief-specific content. It does NOT restate global rules (DoD, image paths, user roles, trusted sources, final-report structure) — it references the relevant Section in `CLAUDE.md`.

You are creating product documentation from textual requirements (briefs, epics, PRDs, user stories). Approved sources, user roles, image-path rules, and document structure are defined globally in `CLAUDE.md` — this skill only adds what is unique to working from text.

---

## 1. When to Use

- The user provides written requirements: a brief, epic, PRD, user story, or feature description.
- There is no visual design or live product to observe as the primary source.

---

## 2. Pre-Flight Checklist (BLOCKING)

This is the brief-specific expansion of `CLAUDE.md` Section 0 (Pre-Writing) and Section 1 (Trusted Sources). Before writing:

1. **Read the entire brief/epic** from start to finish.
2. **Identify all user stories** / feature requirements.
3. **Extract acceptance criteria** — these become business rules.
4. **Note stated assumptions, constraints, and out-of-scope items.**
5. **Identify gaps** — what's missing or unclear (drives clarification questions, §3).
6. **Check `.claude/lesson-learned.md`** for relevant entries (Rule 3).

⛔ **Blocking:** Do NOT proceed until the brief is fully analyzed and all gaps identified.

**Brief-specific source principle:** Treat acceptance criteria as blocking business rules; document stated assumptions explicitly; **do NOT invent features or assume behavior not in the brief** — ask for clarification instead.

---

## 3. Core Workflow (brief-specific)

### Asking Clarification Questions

Briefs often lack detail. When information is missing or ambiguous, ask **specific, actionable** questions.

| Missing Info | Example Question |
|--------------|------------------|
| **UI behavior** | "When the user clicks 'Export', does it download immediately or show a confirmation dialog?" |
| **Business rules** | "What is the maximum file size for uploads? Different for premium vs. free?" |
| **Edge cases** | "What shows when the video list is empty — an empty state with a CTA, or a blank page?" |
| **User roles** | "Can all roles access this feature, or only specific roles defined in the product's `CLAUDE.md` §3?" |
| **Messages** | "What exact message appears on successful upload? Include the video title or generic?" |
| **Metrics/KPIs** | "What formula defines 'engagement rate'?" |

❌ Too vague: "Can you clarify the upload flow?"
✅ Specific: "If the user uploads a file larger than 10GB, do we show an error before upload starts or after?"

If questions go unanswered, use `[CLARIFICATION NEEDED: ...]` placeholders in the doc and list them under "Pending Questions" in the final report.

### Inferring Scenarios from User Stories

Transform each `As a [role], I want [action], so that [benefit]` story into a complete scenario (Purpose, Roles, Preconditions, Flow, Postconditions — per `CLAUDE.md` §4). Example:

```markdown
## سناریو: فیلتر ویدیوها بر اساس وضعیت انتشار

**هدف:** یافت سریع ویدیوها بر اساس وضعیت (پیش‌نویس، منتشرشده، آرشیو)

**پیش‌نیازها:** کاربر حداقل یک ویدیو دارد و در «ویدئوهای من» است

**فلو اصلی:**
1. کاربر روی «فیلتر» کلیک می‌کند
2. سیستم منوی فیلتر را نمایش می‌دهد (همه، منتشرشده، پیش‌نویس، آرشیو)
3. کاربر «پیش‌نویس» را انتخاب می‌کند
4. سیستم لیست را فیلتر کرده و تعداد نتایج را نمایش می‌دهد

**پیامدها:**
- وضعیت فیلتر تا پاک‌کردن یا خروج حفظ می‌شود
- اگر نتیجه‌ای نباشد: [CLARIFICATION NEEDED: چه پیامی نمایش داده شود؟]
```

> Brief-based scenarios will have more `[CLARIFICATION NEEDED]` markers than design-based ones, since briefs lack visual detail.

### Handling Missing Visual Information

Briefs lack UI detail. Strategies:
1. **Reference existing patterns:** link to a similar already-documented feature.
2. **Describe behavior, not appearance:** "Clicking 'Save' triggers form validation" — not "blue rounded button".
3. **Request mockups if critical:** note that visual details await design.
4. **Use placeholders:** `![توضیح تصویر - در انتظار طراحی](/img/my-videos/filter-placeholder.png)` with a note that the image will be added after design.

### Creating Business Rules from Acceptance Criteria

Convert each acceptance criterion into an explicit, specific business rule (limits, formats, validations, error handling, transcoding, progress, etc.). Mark any criterion that is ambiguous with `[CLARIFICATION NEEDED: ...]`.

### Handling Ambiguous Specifications

| Ambiguous Language | How to Handle |
|--------------------|---------------|
| "Users can…" | Which roles? All or specific? Own items only? |
| "The system should…" | When? Under what conditions? Which channel? |
| "If needed…" | What defines "needed"? What triggers it? |
| "Approximately…" | Exact value or range? Hard limit? |
| "Soon…" | Define the timeline (next release? undefined?) |

When clarification isn't available, document the ambiguity explicitly in the doc.

---

## 4. DoD Additions (brief-specific deltas only)

- Scenarios are inferred from user stories but must still meet the full scenario rule in `CLAUDE.md` §4 (Purpose, Preconditions, Flow, Postconditions; inline images when available).
- Business rules must be explicit and specific per `CLAUDE.md` §5 — convert vague brief language into concrete rules or mark as `[CLARIFICATION NEEDED]`.

---

## 5. Final Report Additions (brief-specific fields)

The base final-report structure is defined in `CLAUDE.md` Section 8. In addition, a brief-sourced report MUST include:

- **Brief sources:** document title, date, author, version; the user-story IDs addressed; how many acceptance criteria were used.
- **Clarifications log:** questions asked / answered / pending (the pending list mirrors the `[CLARIFICATION NEEDED]` markers in the doc).

---

## 6. Completion Checklist

**Mandatory self-verification (before delivery):** run the `lore:doc-reviewer` subagent (Task tool) on the produced document(s). If it reports any BLOCKING failure (§0/§1/§4/§6/§8, Rule 3, Rule 4), fix and re-run until it returns green. Only then write the final report (§8). This does not duplicate the DoD — it invokes the canonical validator.

- [ ] `lore:doc-reviewer` run and returned APPROVED (no blocking failures)
- [ ] Entire brief read and analyzed; all gaps identified
- [ ] All user stories documented as complete scenarios (per `CLAUDE.md` §4)
- [ ] All acceptance criteria converted to explicit business rules
- [ ] Clarification questions asked; placeholders used for unanswered items
- [ ] No invented features or assumptions
- [ ] Final report includes brief details + Q&A log
- [ ] All BLOCKING rules from the global DoD satisfied

---

## 7. Reference Example

See [examples/feature-from-epic.md](examples/feature-from-epic.md) for a complete example of documentation generated from a product brief.
