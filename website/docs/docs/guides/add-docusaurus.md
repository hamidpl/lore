---
sidebar_position: 5
title: Add the Docusaurus viewer
description: Use /lore:add-docusaurus to turn a Markdown-only Lore project into a browsable site, with RTL styling when the documentation language is right-to-left.
tags: [guides, docusaurus]
---

# Add the Docusaurus viewer

A Lore project can start as **Markdown only** and gain a browsable website later. **`/lore:add-docusaurus`** does exactly that.

```text
/lore:add-docusaurus
```

## What it does

1. **Checks preconditions** — you need a network connection, and the project must be docs-only (it has documentation but no viewer yet).
2. **Fetches the latest Docusaurus.** The framework itself is pulled fresh with `create-docusaurus@latest` — it is never bundled, so you always get the current release.
3. **Imports the framework and discards the samples** (the starter docs, blog, and pages) so they don't collide with your content.
4. **Overlays the Lore configuration and styling**, including the [RTL layer](../concepts/multilingual-rtl.md) and self-hosted Persian font when your documentation language is right-to-left.
5. **Wires the sidebar** to mirror your existing `docs/` tree, then installs, builds, and points you at the preview.

## Result

A Docusaurus site wired to your existing docs, ready to preview:

```bash
npm start         # dev server at http://localhost:3000
npm run build     # production build — must pass before delivery
npm run serve     # preview the production build
```

:::tip Keeping Docusaurus up to date
Because the viewer is a normal npm project, Docusaurus is a versioned dependency in its `package.json`. Update it deliberately with `npm update` (minor/patch) or by bumping `@docusaurus/*` and running `npm install` for a major, then re-running the build.
:::
