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

1. **Pre-flight.** Confirms the browser tools are available, asks once how to run (approve each step, or run uninterrupted), and pins which routes and features to explore. If a feature needs a login, you sign in once in the headed browser and the session persists.
2. **Scenario scripts.** Each feature gets a small, re-runnable scenario — a list of steps, each with an action, a screenshot name, and optional text to wait for. These are internal artifacts; they never appear in the published docs.
3. **Browser automation.** The heavy browsing is delegated to the **`lore:site-explorer`** subagent, which performs the steps, reads the **exact UI text** from the accessibility snapshot, captures deterministic screenshots, and returns a compact summary.
4. **Validation and report.**

## Systematic coverage

Every feature is exercised across four dimensions:

- **Happy path** — the successful end-to-end journey.
- **Validation errors** — empty fields, invalid data, oversized files; the *exact* error text is recorded.
- **Edge cases** — empty states, maximum values, network failures, rapid or duplicate actions.
- **Roles & permissions** — how each role's view and access differ.

## Free QA on the side

Documenting a live product surfaces real defects. Discrepancies between the design/brief and the actual behavior are flagged, and genuine product defects are consolidated into structured **bug drafts** (title, severity, steps to reproduce, screenshot). You can optionally file them as GitHub issues — the default is drafts on disk.

## Deterministic by design

Screenshots use a fixed viewport (1280×720 by default, or a mobile preset) and stable waits — never fixed sleeps — so the images are consistent and diffable. UI text is read from the accessibility tree, not pixels, which is both exact and cheap.
