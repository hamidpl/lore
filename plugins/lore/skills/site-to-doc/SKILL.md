---
name: site-to-doc
description: Generate or update documentation based on live product observation. Use this when documenting existing features, verifying actual behavior, or when the user mentions "live site", "production", "actual behavior", or asks to document how something currently works.
user-invocable: true
---

# Live Site to Documentation Skill

**This skill provides input-specific instructions for documenting from live product observation. It complements (does not override) the global system prompt in `.claude/CLAUDE.md`.**

> **GOLDEN RULE (Rule 4 — Single Place of Truth):** This skill contains ONLY live-site-specific content. It does NOT restate global rules (DoD, image paths, user roles, trusted sources, final-report structure) — it references the relevant Section in `CLAUDE.md`.

You document features by **driving a real browser** through the live product: you run a user-defined scenario step by step, capture a screenshot at each step, and read exact UI text from the page — then write documentation from what you observed. Approved sources, user roles, image-path rules, and document structure are defined globally in `CLAUDE.md` — this skill only adds what is unique to observing a running product.

---

## 1. When to Use

- The user asks to document actual behavior, or mentions "live site", "production", "actual behavior", or the product URL.
- The primary source is the running product (not a Figma design or a brief).
- **Scope:** browser-based web products. Native mobile apps are out of scope for this skill (a mobile-web/responsive **viewport** of a web product is in scope — see §3 capture rules).

---

## 2. Pre-Flight Checklist (BLOCKING)

This is the live-site expansion of `CLAUDE.md` Section 0 (Pre-Writing) and Section 1 (Trusted Sources). Complete IN ORDER before writing:

1. **Browser tooling available?** Confirm the **Playwright MCP** browser tools are reachable (look for a `browser_navigate` / `browser_snapshot` tool). If they are not, **stop** and give the user the one-line install command, then wait:
   ```
   claude mcp add playwright -- npx @playwright/mcp@latest
   ```
   (See the [Lore README](https://github.com/hamidpl/lore) — it is the single source of truth for setup commands, Rule 4. For a degraded path when the tools cannot be enabled, see "Fallback" in §3.)
2. **Resolve the URL and scope.** Take the site URL from `CLAUDE.md` §1 (or one the user provides). **Pin the crawl scope explicitly** — which routes/features, and roughly how many pages — and confirm it with the user. Do NOT start exploring without an agreed scope.
3. **Login Checkpoint** — if any part of the scope is behind authentication, complete the login handshake in §3 before exploring.
4. **Scenario script** — build or collect the step-by-step scenario(s) and finalize them with the user (format in §3).
5. **Check `.claude/lesson-learned.md`** for relevant entries (Rule 3).

⛔ **Blocking:** Do NOT proceed to write until the feature has been systematically exercised in its live environment via the agreed scenarios.

**Site-specific source principle:** Document what **IS**, not what **SHOULD BE** — capture actual current behavior and exact UI text; never invent or assume behavior, observe it.

---

## 3. Core Workflow (live-site-specific)

### Scenario Script (canonical format — Rule 4)

A scenario script is the **re-runnable artifact** that defines what to exercise and what to capture. Store it at `.claude/scenarios/{feature}.yaml` in the consuming repo (inside `.claude/`, so it is out of the hooks' scope). Because it is saved, **updating the docs after the product changes is cheap**: re-run the same script and only the changed screenshots/behaviors are refreshed.

```yaml
scenario: Upload a video
section: upload          # → images go to static/img/upload/
viewport: 1280x720       # optional; defaults to 1280x720
steps:
  - action: navigate to /upload
    shot: upload-01-initial          # → static/img/upload/upload-01-initial.png
    expect: "Drag your file here"    # optional: text/condition to wait for (no blind sleeps)
  - action: choose a 4GB file
    shot: upload-02-size-error
    expect: "exceeds the maximum"
  - action: click Publish with empty title
    shot: upload-03-validation
```

Each step is one action + one `shot` (the screenshot's descriptive name) + an optional `expect`. The on-disk image name follows `{feature}-{NN}-{state}.png` (NN = step number) so captures sort in flow order.

### Running the scenario (delegate the heavy part)

Delegate the actual browser run to the **`lore:site-explorer`** subagent (Task tool) — it drives Playwright MCP, walks each step, captures screenshots to disk, and returns a compact summary (steps→images, verbatim UI strings, observed business rules, open questions). This keeps the heavy, context-bloating browsing out of the main context. Writing prose and asking the user clarifying questions stay here in the main context — the subagent is autonomous and cannot ask questions.

Pass the subagent: the base URL, the scenario script(s), the viewport, the `static/img/{section}/` target, and the page budget. The subagent shares this session's MCP connection — so a session you logged into during the Login Checkpoint is already authenticated for it.

> **Fallback (no subagent MCP access):** if the `lore:site-explorer` subagent cannot reach the browser tools in your environment, run the scenario **in the main context** using the same `browser_*` tools directly — but warn the user this consumes more tokens, and keep the page budget tight.

### Capture rules

- **Deterministic viewport:** resize to **1280×720** before capturing (`browser_resize`) so images are stable across runs and diffs between doc versions are meaningful. A **mobile preset** (`390×844`) is available for documenting the responsive/mobile-web view — use it only when the user asks.
- **Naming:** `{feature}-{NN}-{state}.png` (e.g. `upload-01-initial.png`, `upload-02-size-error.png`, `my-videos-01-empty-state.png`).
- **Shot type:** **viewport** shot by default; `fullPage` only for genuinely long pages where the whole scroll matters.
- **Stability over sleeps:** wait on a text/element/condition (`browser_wait_for`), never a fixed delay.
- **Read text from the snapshot, not the picture:** capture exact UI labels and messages from the accessibility snapshot (`browser_snapshot`) — it is exact and cheaper than reading pixels.
- **Sensitive data:** before capturing, make sure no real sensitive data is on screen — use a **test account** with sample data. Screenshots are committed to the repo.
- Storage/reference paths (`static/img/` on disk, `/img/` in markdown, never `/static/img/`, never under `docs/`) are global — see `CLAUDE.md` Section 6 + Rule 1.

### Login Checkpoint (authentication-gated areas)

The pattern is **"the human logs in once, automation continues."** A password is never typed into the chat or read by the model.

1. Have the browser open the product's login page (headed — it is headed by default).
2. Ask the user to **log in manually in that browser window** (2FA / SSO are fine — the user completes them in the browser).
3. The user tells you they are done; confirm via `browser_snapshot` that an authenticated state is visible (e.g. the account menu) before continuing.
4. Explore. Playwright MCP uses a **persistent browser profile by default**, so the login state and cookies **persist between runs** — later runs skip the login step automatically.

**Optional — export the session for clean/isolated runs:** you may export the authenticated state with `browser_storage_state` to `.claude/.auth/{host}.json` and re-inject it (`browser_set_storage_state`, or start the server with `--isolated --storage-state=...`). If you do:

- ⛔ **First ensure `.claude/.auth/` is git-ignored.** Check `.gitignore`; if the entry is missing, add `.claude/.auth/` before writing the file.
- ⛔ A saved session file contains cookies/headers that can be used to **impersonate** the account — treat it as a secret. Never commit it, never paste its contents into chat, the docs, or the final report.
- When the server-side session expires, repeat the Login Checkpoint.

> Credentials are never the model's to hold: do not ask the user to paste a password, do not echo secrets, and do not write them anywhere. (Playwright MCP also supports a `--secrets` dotenv file for values the browser may need — credentials live there or in the user's hands, never in chat.)

### Token economy (keep this skill cheap)

- Navigate and read text from **accessibility snapshots**, not screenshots — the snapshot is structured text, far lighter than sending images to the model.
- Screenshots are **saved to disk only**; do not pull captured images back into context (spot-check 1–2 at most for quality).
- Push the heavy browsing into the **`lore:site-explorer`** subagent so its verbose tool traffic never enters the main context — only the compact summary returns.
- **Default budget: ~3 scenarios / ~10 pages per run.** Going beyond needs explicit user confirmation.
- **Update mode is cheap by design:** when the product changes, re-run only the affected saved scenario script(s); unchanged captures and prose stay as-is.

### Systematic Testing Approach

Exercise each feature across four dimensions (encode these as steps in the scenario script):

**1. Happy Path** — walk the intended successful journey end to end, capturing each significant state (initial → action → progress → success → result).

**2. Validation Errors** — empty required fields, invalid data (special chars, too long), wrong file type, oversized file, submit-with-errors. Record the **exact** error text for each.

**3. Edge Cases** — empty list / empty state, maximum values (character/file-size limits), network failure mid-operation, slow connection (loading states/timeouts), multiple rapid clicks (duplicate-action protection).

**4. Permission & Role Tests** — observe each role's view and access differences (roles per `CLAUDE.md` §3). Note which roles you could and could not test.

### Screenshot Strategy

Capture: initial state, each significant state change, all error states, success confirmations, empty states, loading states, and role variations — each as a numbered step in the script, stored under `static/img/{section}/`.

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

  ![حالت خالی ویدئوهای من](/img/my-videos/my-videos-01-empty-state.png)

  سیستم نمایش می‌دهد:
  - پیام: "هنوز ویدیویی آپلود نکرده‌اید"
  - دکمه CTA: "اولین ویدیو خود را آپلود کنید"
  ```

- **Maximum values:** actual character/size limit, whether the field blocks input beyond it, counter presence, paste behavior.
- **Network failures:** error message shown, retry possibility, resume vs. restart.
- **Rapid actions:** does the button disable after first click? are duplicate requests sent?

### Technical Details (optional)

Where the user wants technical depth, have the run also collect (via the MCP `browser_console_messages` / `browser_network_requests` tools): API endpoints called (request/response shape), JavaScript errors, network failures/timeouts, and load/response times. Document under a "Technical Details" subsection (heading in the project's documentation language, §7 — e.g. Persian "اطلاعات فنی").

---

## 4. DoD Additions (live-site-specific deltas only)

- Screenshots are the live-site equivalent of Figma image extraction: place each inline at the scenario step it illustrates (the scenario/image rule is global — `CLAUDE.md` §4).
- Capture all system messages verbatim from the snapshot to satisfy the accuracy requirement (`CLAUDE.md` §5).

---

## 5. Final Report Additions (live-site-specific fields)

The base final-report structure is defined in `CLAUDE.md` Section 8. In addition, a live-site report MUST include:

- **URLs tested** + test environment (browser, viewport, OS, network, date).
- **Scenario scripts** run (paths under `.claude/scenarios/`).
- **Authentication method** used (manual Login Checkpoint / reused persistent session / injected storage-state) — **never any secret or file contents**.
- **User roles tested** vs. could-not-test (with reason).
- **Screenshots captured** (count + storage directories).
- **Budget used** (scenarios / pages) against the default.
- **Discrepancies found** between design/brief and live site.
- **Edge cases tested** and any unexpected/undocumented behaviors discovered.

---

## 6. Completion Checklist

**Mandatory self-verification (before delivery):** run the `lore:doc-validator` subagent (Task tool) on the produced document(s). If it reports any BLOCKING failure (§0/§1/§4/§6/§8, Rule 3, Rule 4), fix and re-run until it returns green. Only then write the final report (§8). This does not duplicate the DoD — it invokes the canonical validator.

- [ ] `lore:doc-validator` run and returned APPROVED (no blocking failures)
- [ ] Playwright MCP tooling confirmed available (or install command given and resolved)
- [ ] Crawl scope agreed with the user before exploring
- [ ] Scenario script(s) saved under `.claude/scenarios/`
- [ ] Happy path, validation errors, and edge cases exercised
- [ ] Exact UI text / error messages captured verbatim (from snapshots)
- [ ] Screenshots captured for all significant states, named `{feature}-{NN}-{state}.png` under `static/img/{section}/`
- [ ] No screenshot images pulled into context beyond a 1–2 image spot-check
- [ ] Role differences tested where possible (roles per `CLAUDE.md` §3)
- [ ] If a session was exported, `.claude/.auth/` is git-ignored and no secret reached chat/docs/report
- [ ] Discrepancies between design and reality flagged
- [ ] Final report includes URLs, scenarios, auth method, roles, screenshots, budget, discrepancies
- [ ] All BLOCKING rules from the global DoD satisfied

---

## 7. Reference Example

See [examples/actual-behavior.md](examples/actual-behavior.md) for a complete example of documentation generated from live site observation.
