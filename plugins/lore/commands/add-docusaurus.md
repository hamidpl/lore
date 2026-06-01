---
description: Add the Docusaurus viewer (browsable site) to an existing docs-only Lore project, with RTL styling if the documentation language is right-to-left.
---

# /lore:add-docusaurus — Add the Docusaurus viewer to a docs-only project

The user has a Lore documentation project that is **docs-only** (Markdown in `docs/`, config in `.claude/`, but no `docusaurus.config.ts`). Add the Docusaurus site layer so the docs render as a browsable website. Keep your messages and config in **English**.

## Step 0 — Preconditions

- Resolve the plugin root (env `${CLAUDE_PLUGIN_ROOT}` or this file's `../`); you need `scripts/scaffold.sh` and the `templates/`.
- Run `sh "$PLUGIN_ROOT/scripts/detect-project.sh"`:
  - `has-docusaurus` → already installed; tell the user and stop.
  - `empty` / `non-empty` (no docs) → suggest `/lore:init` instead and stop.
  - `docs-only` → proceed.

## Step 1 — Determine the language

Read the documentation language / locale from `.claude/CLAUDE.md` (the Content language line and the Locale/Direction line). If it's ambiguous, ask the user (RTL e.g. Persian vs LTR e.g. English). Derive `LOCALE`, `DIRECTION`, `HTML_LANG`, `LANG_LABEL`, and whether RTL.

## Step 2 — Copy the viewer layer(s)

```bash
sh "$PLUGIN_ROOT/scripts/scaffold.sh" --target . --layer docusaurus   # + --layer rtl if RTL
```

Existing files are never overwritten (the script guards this), so `docs/` and `.claude/` stay intact.

## Step 3 — Fill config + wire the sidebar to existing docs

- `package.json`: `{{PROJECT_SLUG}}`.
- `docusaurus.config.ts`: title/tagline/slug/org/copyright + i18n (`{{LOCALE}}`, `{{LANG_LABEL}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`). Pull product name/description from `.claude/CLAUDE.md`. **RTL:** set `customCss` to `['./src/css/custom.css', './src/css/custom-rtl.css']`; **LTR:** keep `['./src/css/custom.css']`.
- `sidebars.ts`: generate a sidebar that mirrors the **existing** `docs/` tree (one entry per section/folder), not the placeholder example.

## Step 4 — Build + report

Run `npm install && npm run build`. Report success/failure and tell the user how to preview (`npm run serve`). Note that they can change the brand color or language anytime via `/lore:config`.
