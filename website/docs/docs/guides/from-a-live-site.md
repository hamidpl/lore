---
sidebar_position: 3
title: Document from a live site
description: Use lore:site-to-doc to drive a real browser, run scenarios, capture screenshots, and document how a product actually behaves.
tags: [guides, live-site, playwright]
---

# Document from a live site

Use **`lore:site-to-doc`** to document how a product *actually behaves* today — by observing it in a real browser.

```text
lore:site-to-doc <product-url>
```

## Prerequisite: a browser

This skill drives a real browser through the [Playwright MCP](https://github.com/microsoft/playwright-mcp) server. Add it once:

```text
claude mcp add playwright -- npx @playwright/mcp@latest
```

## How a run works

1. **Pre-flight.** Confirms the browser tools are available, asks once how to run (approve each step, or run uninterrupted), pins which routes and features to explore, and asks once whether to also document the responsive view (mobile 390×844, tablet 768×1024, or both) — opt-in, because each extra viewport is a separate browser pass. It also searches your configured trusted sources for material about the routes in scope — the live run is authoritative for behavior, but trusted sources fill in rules the UI doesn't spell out — recording each source's findings in an auditable source census, each row carrying the [receipt](../concepts/definition-of-done.md#evidence-not-attestation) behind it. Anything you asked for in conversation ("cover the signed-in view too") is written down here as a numbered row before browsing starts, and the run cannot be delivered while one is still open.

  If a feature needs a login, you sign in once in the headed browser and the session persists. **Treat each authentication state as a different product**, not as an obstacle to get past: the guest view of an authenticated product is what every new user sees first, and a persistent browser profile will quietly hide it on re-runs. Which states you actually reached — auth state × role × route × viewport, each backed by a screenshot — is recorded as an observation matrix, so a guest-only run is visible as such rather than implied.
2. **Scenario scripts.** Each feature gets a small, re-runnable scenario — a list of steps, each with an action, a screenshot name, and optional text to wait for. These are internal artifacts; they never appear in the published docs.
3. **Browser automation.** The heavy browsing is delegated to the **`lore:site-explorer`** subagent, which performs the steps, reads the **exact UI text** from the accessibility snapshot, captures deterministic screenshots, and returns a compact summary. When every pass is done, the screenshots are compressed in one batch — typically around 70% smaller at the same dimensions, with no visible difference. Screenshots are committed to your repository and served by your site, so this is where that weight is reclaimed; the compressor leaves a file untouched rather than push it past its quality floor, and a machine with no image optimizer installed is told so instead of being given a saving that never happened.
4. **Validation and report.**

## Systematic coverage

Every feature is exercised across four dimensions:

- **Happy path** — the successful end-to-end journey.
- **Validation errors** — empty fields, invalid data, oversized files; the *exact* error text is recorded.
- **Edge cases** — driven by the documentation template's edge-case taxonomy, in rough defect-frequency order: limits get a three-value probe (just below, at, just above — e.g. 99/100/101), and state transitions are exercised too (Back mid-flow, direct URL entry into a mid-flow state), alongside empty states and network failures.
- **Roles & permissions** — how each role's view and access differ.

## Free QA on the side

Documenting a live product surfaces real defects. Discrepancies between the design/brief and the actual behavior are flagged, and genuine product defects are consolidated into structured **bug drafts** (title, severity, steps to reproduce, screenshot). You can optionally file them as GitHub issues — the default is drafts on disk.

## Deterministic by design

Screenshots use a fixed viewport (1280×720 by default, or a mobile/tablet preset when you opt into a responsive pass) and stable waits — never fixed sleeps — so the images are consistent and diffable. When a responsive pass runs, the scenario re-runs at the smaller viewport and only the differences are captured into a **Mobile & Tablet View** section (mobile shots display at half width). UI text is read from the accessibility tree, not pixels, which is both exact and cheap.
