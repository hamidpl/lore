---
name: site-to-doc
description: Generate or update documentation based on live product observation. Use this when documenting existing features, verifying actual behavior, or when the user mentions "live site", "production", "actual behavior", or asks to document how something currently works.
argument-hint: [product-url]
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
2. **Run mode — ask once, before any browsing.** Each browser action (`browser_*`) otherwise triggers a per-step permission prompt — tedious across a multi-step scenario, and the run is delegated to the `lore:site-explorer` subagent so the prompts fire mid-run. Ask the user which they want:
   - **Uninterrupted (recommended for real runs):** offer to add the Playwright MCP server to the project allowlist — `permissions.allow` in `.claude/settings.json` with the entry `mcp__playwright`. This one approval pre-authorizes every `browser_*` call **including the subagent's**, so the scenario runs end-to-end without further prompts. Tell the user it can be removed later via `/permissions`.
   - **Approve each step:** keep the default — every browser action prompts. (Use when the user wants to watch each action.)

   If the user doesn't choose, default to approve-each-step (the safe default). See the [Lore README](https://github.com/hamidpl/lore) for setup/permission specifics (Rule 4).
3. **Resolve the URL and scope.** Take the site URL from `CLAUDE.md` §1 (or one the user provides). **Pin the crawl scope explicitly** — which routes/features, and roughly how many pages — and confirm it with the user. Do NOT start exploring without an agreed scope.
4. **Login Checkpoint** — if any part of the scope is behind authentication, complete the login handshake in §3 before exploring.
5. **Plan the run (scenario optional).** This skill has two modes:
   - **Full-page documentation** — the user has no specific scenario and just wants one or more pages documented completely. Build an internal exploration plan that systematically exercises each target page (happy path + validation + edge cases per §3).
   - **Specific scenario** — the user has a particular flow to exercise. Build or collect the step-by-step scenario(s) and finalize them with the user (format in §3).

   Either way, any scenario script you write is a **purely internal re-run artifact** (stored under `.claude/`, §3) — it is never named, linked, or surfaced in the published documentation (Rule 5). When planning, if a target page's scenarios will exceed the §2 split threshold, plan it as a multi-page section (overview `index.md` + sibling sub-pages) per the `CLAUDE.md` §2 split rule.
6. **Responsive coverage — ask once, before running.** Unlike Figma (where device frames are already fetched), each extra viewport here is a **separate browser pass** over the key routes — real token/time cost. So ask the user explicitly whether to also document the responsive view, offering: **none — desktop only** (default), **mobile** (`390×844`), **tablet** (`768×1024`), or **both**. Warn that each chosen viewport re-runs the key steps of the scenario. If the user doesn't choose, default to desktop-only and note it in the final report. Record the decision — it drives the responsive pass in §3 and the Mobile & Tablet View section.
7. **Check `.claude/lesson-learned.md`** for relevant entries (Rule 3).

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

⛔ **The scenario script is an internal authoring artifact — never surface it in the output (Rule 5).** Do not name it, link it, embed its YAML, or write its `.claude/scenarios/...` path anywhere in the published documentation. Readers see the flow only as product-facing prose in the document's **Scenarios** section (the standard Purpose / Roles Involved / Preconditions / Main Flow / Extensions / Postconditions structure) — written from the user's perspective, with no mention of the script, the browser tooling, or any `.claude/` path. Observed error, validation, and empty states go in each scenario's **Extensions** section (per `CLAUDE.md` §4 + the template).

### Running the scenario (delegate the heavy part)

Delegate the actual browser run to the **`lore:site-explorer`** subagent (Task tool) — it drives Playwright MCP, walks each step, captures screenshots to disk, and returns a compact summary (steps→images, verbatim UI strings, observed business rules, open questions). This keeps the heavy, context-bloating browsing out of the main context. Writing prose and asking the user clarifying questions stay here in the main context — the subagent is autonomous and cannot ask questions.

Pass the subagent: the base URL, the scenario script(s), the viewport, the `static/img/{section}/` target, and the page budget. The subagent shares this session's MCP connection — so a session you logged into during the Login Checkpoint is already authenticated for it.

**Responsive pass (only if the user opted in at Pre-Flight step 6).** Re-run the **same** scenario script through `lore:site-explorer` at the chosen preset (`390×844` and/or `768×1024`), but scope it to a **differences pass** — the happy-path steps plus any state whose layout or behavior visibly changes on a small screen — not a full re-capture of every step. Tell the subagent the target sub-path (`mobile/` or `tablet/`). Its captures + observed differences feed **only** the template's Mobile & Tablet View section (differences from desktop — never a re-told flow). This extra pass counts against the page/scenario budget below.

> **Fallback (no subagent MCP access):** if the `lore:site-explorer` subagent cannot reach the browser tools in your environment, run the scenario **in the main context** using the same `browser_*` tools directly — but warn the user this consumes more tokens, and keep the page budget tight.

### Capture rules

- **Deterministic viewport:** resize to **1280×720** before capturing (`browser_resize`) so images are stable across runs and diffs between doc versions are meaningful. Two responsive presets — **mobile `390×844`** and **tablet `768×1024`** — are available for documenting the responsive/mobile-web view; run them **only when the user opted in at Pre-Flight step 6**. Route those captures to `static/img/{section}/mobile/…` and `static/img/{section}/tablet/…` respectively (same `{feature}-{NN}-{state}.png` naming). The `/mobile/` sub-path makes those tall shots render at half width on desktop — that display convention is global (`CLAUDE.md` §6); just follow the path.
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
- **Default budget: ~3 scenarios / ~10 pages per run.** Going beyond needs explicit user confirmation. A responsive pass (a second/third viewport) counts against this budget — which is why it is opt-in (Pre-Flight step 6).
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

**Documentation format for a discrepancy** (write in the project's documentation language, §7; the example below is in English):

```markdown
## Current System Behavior

### Video Upload

**Behavior observed on the live site:**
- Maximum file size: 3 GB
- Error message: "File size exceeds the limit. Maximum 3GB"

**Designed behavior (Figma v2.1):**
- Maximum file size: 6 GB (standard), 12 GB (premium)

**Status:**
⚠️ Design and implementation differ. Needs product-team confirmation.
[CLARIFICATION REQUESTED: Document current 3GB limit or planned 6GB/12GB?]
```

**Flag** discrepancies when: a feature exists in design but not live, behavior differs significantly, error messages don't match, or roles have different access than designed. **Don't flag** minor styling (colors, fonts) or button positioning unless it affects the workflow.

### Edge Case Walkthroughs

- **Empty states:** Is there an empty-state message and a CTA? Capture exact text. Example (write in the project's documentation language, §7; shown in English):

  ```markdown
  ### Empty State

  ![My Videos empty state](/img/my-videos/my-videos-01-empty-state.png)

  The system displays:
  - Message: "You haven't uploaded any videos yet"
  - CTA button: "Upload your first video"
  ```

- **Maximum values:** actual character/size limit, whether the field blocks input beyond it, counter presence, paste behavior.
- **Network failures:** error message shown, retry possibility, resume vs. restart.
- **Rapid actions:** does the button disable after first click? are duplicate requests sent?

### Technical Details (optional)

Where the user wants technical depth, have the run also collect (via the MCP `browser_console_messages` / `browser_network_requests` tools): API endpoints called (request/response shape), JavaScript errors, network failures/timeouts, and load/response times. Document under a "Technical Details" subsection (heading in the project's documentation language, §7).

### Surfacing Observed Issues (optional bug drafts)

Documenting a live product is also a free QA pass: the run already surfaces real defects. After the scenario run, **consolidate** them into ready-to-file bug drafts — don't leave them buried as inline `⚠️` flags.

**What qualifies (product defects only):** from the `lore:site-explorer` summary, take the **Unexpected / undocumented behavior**, the **discrepancies you flagged** (per "Handling Discrepancies Between Design and Reality"), and any **failed step that is a genuine product defect**. ⛔ **Exclude scenario-authoring failures** — a wrong selector, a navigation timeout on your side, or a budget stop is the explorer's own problem, not a product bug. When unsure whether a failed step is a defect or a script issue, leave it as an open question for the user, not a draft.

**If nothing qualifies:** note "No product anomalies observed" in the final report and skip this step entirely (no empty file).

**Otherwise — write a sidecar file** at `.claude/observed-issues/{YYYY-MM-DD}-{slug}.md` (one file per run; under `.claude/`, so it is out of the hooks' scope and never mixed into the product docs). ⛔ It is an internal artifact — never reference it, or its `.claude/observed-issues/...` path, anywhere in the published documentation (Rule 5). It is safe to commit (like scenario scripts — it is not a secret). One draft per defect, using this fixed template:

```markdown
### [Bug] {short title}
**Type:** bug | discrepancy
**Severity (guess):** low | medium | high
**Where:** {feature / route} — scenario step {NN}
**Expected:** {intended behavior, or what the design/brief says}
**Actual:** {observed behavior, with verbatim UI text}
**Steps to reproduce:**
1. ...
**Screenshot:** static/img/{section}/{shot}.png
**Environment:** {url, browser, viewport, date}
**Source:** observed during site-to-doc run, {date}
```

⛔ **Privacy guard (same credential discipline as §3 Login Checkpoint):** a draft must never contain a password, token, storage-state content, or an absolute local path. Reference screenshots by their **repo-relative** `static/img/…` path only. If a verbatim string would leak sensitive data, redact it.

**Then offer to file (never automatic).** Only when **all** of these hold — `gh` is on `PATH`, `gh auth status` exits 0, and the repo has a GitHub remote — ask **once**: *"Found N observed issues — file them in {owner/repo} as GitHub issues, or leave them as drafts in {path}?"* Default is **drafts only**; filing requires explicit confirmation **each run**. On confirm, create one issue per draft with `gh issue create --title … --body … [--label …]` and echo each returned issue URL. GitHub only (no `glab`). `gh` cannot upload the screenshot binary via the body, so keep the repo-relative path in the issue and tell the user they can drag-drop the image into the issue afterward. If `gh` is missing or unauthenticated, **don't offer** — leave the drafts on disk and tell the user where they are and that they can file them manually.

See [examples/observed-issues.md](examples/observed-issues.md) for a filled sidecar file.

---

## 4. DoD Additions (live-site-specific deltas only)

- Screenshots are the live-site equivalent of Figma image extraction: place each inline at the scenario step it illustrates (the scenario/image rule is global — `CLAUDE.md` §4).
- Capture all system messages verbatim from the snapshot to satisfy the accuracy requirement (`CLAUDE.md` §5).
- **Responsive view:** if the user opted in (Pre-Flight step 6), the **Mobile & Tablet View** section is required (differences only, per the template), with mobile/tablet shots under the `mobile/`/`tablet/` sub-paths. If the user declined, record "responsive view not documented (user declined)" in the final report — the omission is then expected, not a gap.

---

## 5. Final Report Additions (live-site-specific fields)

The base final-report structure is defined in `CLAUDE.md` Section 8. The Final Report is delivered **in chat** at task completion — it is a process deliverable for the user and is **never written into a documentation file** (the reader-facing docs are governed by Rule 5; the report below may name the skill/subagents and internal `.claude/` paths because the user, not the product's readers, is its audience). In addition, a live-site report MUST include:

- **URLs tested** + test environment (browser, OS, network, date) and **every viewport run** (desktop `1280×720`, plus mobile `390×844` / tablet `768×1024` if a responsive pass ran).
- **Responsive coverage:** which viewports the user opted into at Pre-Flight step 6 (or "desktop only — declined"), and whether the Mobile & Tablet View section was produced.
- **Scenario scripts** run (paths under `.claude/scenarios/`).
- **Authentication method** used (manual Login Checkpoint / reused persistent session / injected storage-state) — **never any secret or file contents**.
- **User roles tested** vs. could-not-test (with reason).
- **Screenshots captured** (count + storage directories).
- **Budget used** (scenarios / pages) against the default.
- **Discrepancies found** between design/brief and live site.
- **Edge cases tested** and any unexpected/undocumented behaviors discovered.
- **Observed issues drafted** — count + sidecar path (`.claude/observed-issues/…`), or "none observed"; note whether any were filed to the tracker.

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
- [ ] Responsive coverage decided with the user (Pre-Flight step 6): if opted in, responsive pass run and Mobile & Tablet View section written (mobile/tablet shots under `mobile/`/`tablet/`); if declined, noted in the final report
- [ ] Scenario headings numbered per the template (`Scenario N: …`)
- [ ] No screenshot images pulled into context beyond a 1–2 image spot-check
- [ ] Role differences tested where possible (roles per `CLAUDE.md` §3)
- [ ] If a session was exported, `.claude/.auth/` is git-ignored and no secret reached chat/docs/report
- [ ] Discrepancies between design and reality flagged
- [ ] Observed product anomalies consolidated into `.claude/observed-issues/…` (or "none observed" noted); no secrets/absolute paths in drafts
- [ ] Final report includes URLs, scenarios, auth method, roles, screenshots, budget, discrepancies
- [ ] No Claude/plugin/internal references in the published docs — no `.claude/` paths, no scenario-script mention, no `lore:*` names (Rule 5)
- [ ] All BLOCKING rules from the global DoD satisfied

---

## 7. Reference Example

See [examples/actual-behavior.md](examples/actual-behavior.md) for a complete example of documentation generated from live site observation.
