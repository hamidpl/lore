---
sidebar_position: 1
title: Install & enable
description: Add the Lore marketplace, install the plugin, enable it for your project, and keep it updated.
tags: [getting-started, install]
---

# Install & enable

Lore is a Claude Code plugin distributed through its own marketplace. Installing takes two commands, run **inside Claude Code** (both are idempotent).

## 1. Install

```text
/plugin marketplace add hamidpl/lore       # add the catalog
/plugin install lore@lore-marketplace      # install the plugin
```

For a team or CI repository, install at **project scope** so a clone is self-contained:

```text
/plugin install lore@lore-marketplace --scope project
```

## 2. Enable

**Installed is not the same as enabled.** Installing caches the plugin on your machine; *enabling* turns it on for a project.

If Lore is already installed, don't run `install` again — enable it from the `/plugin` menu (**Installed** → `lore` → Enable), or add it to your project's `.claude/settings.json`:

```json
{ "enabledPlugins": { "lore@lore-marketplace": true } }
```

## Keep it updated

When a new release ships:

```text
/plugin marketplace update lore-marketplace     # refresh the catalog
claude plugin update lore@lore-marketplace      # update the plugin
```

Because Lore ships hooks that run shell scripts in your repository, review plugin updates the way you would any dependency bump.

**Installing Lore does not change how other projects behave.** A plugin is installed per user, so its hooks run in whatever repository you are working in — every one of them checks for a Lore documentation project first and exits immediately otherwise. A project that merely keeps Markdown or images in a folder named `docs` is untouched: the rules here are Lore's Definition of Done, not universal truth.

## Prerequisites

- **[Claude Code](https://code.claude.com/docs/en/overview).** Lore is a Claude Code plugin.
- **A browser, only for [`lore:site-to-doc`](../guides/from-a-live-site.md).** That skill drives a real browser through the [Playwright MCP](https://github.com/microsoft/playwright-mcp) server. Add it once (the skill prompts you if it is missing):

  ```text
  claude mcp add playwright -- npx @playwright/mcp@latest
  ```

## Next

Scaffold your first project with the [Quick start](../getting-started/quick-start.md).
