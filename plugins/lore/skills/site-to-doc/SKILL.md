---
name: site-to-doc
description: Generate or update documentation based on live product observation. Use this when documenting existing features, verifying actual behavior, or when the user mentions "live site", "production", "actual behavior", or asks to document how something currently works.
user-invocable: true
---

# Live Site to Documentation Skill

**This skill provides input-specific instructions for documenting from live product observation. It complements (does not override) the global system prompt in `.claude/CLAUDE.md`.**

> **GOLDEN RULE (Rule 4 — Single Place of Truth):** This skill contains ONLY live-site-specific content. It does NOT restate global rules (DoD, image paths, user roles, trusted sources, final-report structure) — it references the relevant Section in `CLAUDE.md`.

You are documenting features by observing the live product. Approved sources, user roles, image-path rules, and document structure are defined globally in `CLAUDE.md` — this skill only adds what is unique to observing a running product.

---

## 1. When to Use

- The user asks to document actual behavior, or mentions "live site", "production", "actual behavior", or the product URL.
- The primary source is the running product (not a Figma design or a brief).

---

## 2. Pre-Flight Checklist (BLOCKING)

This is the live-site expansion of `CLAUDE.md` Section 0 (Pre-Writing) and Section 1 (Trusted Sources). Before writing:

1. **Access the live site** (URL from `CLAUDE.md` §1, or one provided by the user).
2. **Navigate to the specific feature** being documented.
3. **Test all user flows** systematically (happy path, errors, edge cases — see §3).
4. **Capture screenshots** of each significant state.
5. **Note exact UI text** — labels, buttons, error messages (capture verbatim, never paraphrase).
6. **Test as different user roles** where possible (roles are defined in `CLAUDE.md` §3).
7. **Check `.claude/lesson-learned.md`** for relevant entries (Rule 3).

⛔ **Blocking:** Do NOT proceed until the feature has been systematically tested in its live environment.

**Site-specific source principle:** Document what **IS**, not what **SHOULD BE** — capture actual current behavior and exact UI text; never invent or assume behavior, test it.

---

## 3. Core Workflow (live-site-specific)

### Systematic Testing Approach

Test each feature comprehensively across four dimensions:

**1. Happy Path (success flow)** — walk the intended successful journey end to end, screenshotting each significant state (initial → action → progress → success → result).

**2. Validation Errors** — empty required fields, invalid data (special chars, too long), wrong file type, oversized file, submit-with-errors. Record the **exact** error text for each.

**3. Edge Cases** — empty list / empty state, maximum values (character/file-size limits), network failure mid-operation, slow connection (loading states/timeouts), multiple rapid clicks (duplicate-action protection).

**4. Permission & Role Tests** — observe each role's view and access differences (roles per `CLAUDE.md` §3). Note which roles you could and could not test.

### Screenshot Strategy

Capture: initial state, each significant state change, all error states, success confirmations, empty states, loading states, and role variations. Store screenshots under `static/img/{section}/` with descriptive names (e.g. `upload-form-initial.png`, `upload-size-error.png`, `my-videos-empty-state.png`).

> The image storage/reference path rule (`static/img/` on disk, `/img/` in markdown, never `/docs/`) is global — see `CLAUDE.md` Section 6 + Rule 1.

### Handling Discrepancies Between Design and Reality

When live behavior differs from a Figma design or brief: document both versions (actual vs. designed), flag the discrepancy explicitly, ask the user which to document, and default to current behavior until confirmed.

| Discrepancy Type | How to Handle |
|------------------|---------------|
| **Feature not implemented** | Document as "planned but not yet implemented" |
| **Different UI from design** | Document actual UI, note the design difference |
| **Missing functionality** | Document what exists, note what's missing |
| **Different error handling** | Document actual error behavior |
| **Additional features** | Document discovered features not in designs |

**Documentation format for a discrepancy** (shown for a Persian-language project — write in the project's documentation language, §7):

```markdown
## رفتار فعلی سیستم

### آپلود ویدیو

**رفتار مشاهده‌شده در سایت:**
- حداکثر حجم فایل: 3 گیگابایت
- پیام خطا: "حجم فایل بیش از حد مجاز است. حداکثر 3GB"

**رفتار طراحی‌شده (Figma v2.1):**
- حداکثر حجم فایل: 6 گیگابایت (عادی), 12 گیگابایت (پرمیوم)

**وضعیت:**
⚠️ تفاوت بین طراحی و پیاده‌سازی وجود دارد. نیاز به تایید تیم محصول.
[CLARIFICATION REQUESTED: Document current 3GB limit or planned 6GB/12GB?]
```

**Flag** discrepancies when: a feature exists in design but not live, behavior differs significantly, error messages don't match, or roles have different access than designed. **Don't flag** minor styling (colors, fonts) or button positioning unless it affects the workflow.

### Edge Case Walkthroughs

- **Empty states:** Is there an empty-state message and a CTA? Capture exact text. Example (Persian-language project; use the project's documentation language, §7):

  ```markdown
  ### حالت خالی (Empty State)

  ![حالت خالی ویدئوهای من](/img/my-videos/empty-state-newcomer.png)

  سیستم نمایش می‌دهد:
  - پیام: "هنوز ویدیویی آپلود نکرده‌اید"
  - دکمه CTA: "اولین ویدیو خود را آپلود کنید"
  ```

- **Maximum values:** actual character/size limit, whether the field blocks input beyond it, counter presence, paste behavior.
- **Network failures:** error message shown, retry possibility, resume vs. restart.
- **Rapid actions:** does the button disable after first click? are duplicate requests sent?

### Browser Console Monitoring (for technical detail)

Where relevant, capture: API endpoints called (request/response shape), JavaScript errors, network failures/timeouts, and load/response times. Document under a "Technical Details" subsection (heading written in the project's documentation language, §7 — e.g. Persian "اطلاعات فنی").

---

## 4. DoD Additions (live-site-specific deltas only)

- Screenshots are the live-site equivalent of Figma image extraction: place each inline at the scenario step it illustrates (the scenario/image rule is global — `CLAUDE.md` §4).
- Capture all system messages verbatim to satisfy the accuracy requirement (`CLAUDE.md` §5).

---

## 5. Final Report Additions (live-site-specific fields)

The base final-report structure is defined in `CLAUDE.md` Section 8. In addition, a live-site report MUST include:

- **URLs tested** + test environment (browser, OS, network, date).
- **User roles tested** vs. could-not-test (with reason).
- **Screenshots captured** (count + storage directories).
- **Discrepancies found** between design/brief and live site.
- **Edge cases tested** and any unexpected/undocumented behaviors discovered.

---

## 6. Completion Checklist

**Mandatory self-verification (before delivery):** run the `lore:doc-validator` subagent (Task tool) on the produced document(s). If it reports any BLOCKING failure (§0/§1/§4/§6/§8, Rule 3, Rule 4), fix and re-run until it returns green. Only then write the final report (§8). This does not duplicate the DoD — it invokes the canonical validator.

- [ ] `lore:doc-validator` run and returned APPROVED (no blocking failures)
- [ ] All URLs tested and listed
- [ ] Happy path, validation errors, and edge cases tested
- [ ] Exact UI text / error messages captured verbatim
- [ ] Screenshots captured for all significant states, stored under `static/img/{section}/`
- [ ] Role differences tested where possible (roles per `CLAUDE.md` §3)
- [ ] Discrepancies between design and reality flagged
- [ ] Final report includes URLs, roles, screenshots, discrepancies
- [ ] All BLOCKING rules from the global DoD satisfied

---

## 7. Reference Example

See [examples/actual-behavior.md](examples/actual-behavior.md) for a complete example of documentation generated from live site observation.
