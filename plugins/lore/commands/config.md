---
description: Fill in or edit a Lore documentation project's settings — product description, trusted sources, user roles, doc-writing template, brand color, and the 3 init answers. All questions are skippable.
---

# /lore:config — Configure / edit documentation settings

You configure an existing Lore documentation project (one created by `/lore:init`). You both **fill in** values left as placeholders and **edit** values set earlier. Run anytime; it is idempotent. Keep your messages and the config files in **English** (the documentation *content* language is one of the settings below).

## Step 0 — Confirm context

Ensure `.claude/CLAUDE.md` exists in the cwd (this is a Lore project). If not, tell the user to run `/lore:init` first and stop.

Resolve the plugin root the same way as `/lore:init` (env `${CLAUDE_PLUGIN_ROOT}` or fallback to this file's `../`), in case you need the bundled document template.

## Step 1 — Ask which settings to set (ALL skippable)

Use AskUserQuestion. Every question is optional: tell the user they can **skip** any item and it keeps its current value. Show the current value where one is already set. Cover:

**Deferred settings**
- **Product description** — a short description of the product (used in intro/tagline).
- **Trusted sources (§1)** — Help Center URL, Blog URL, Live product URL. These become the approved sources in the DoD.
- **User roles (§3)** — the product's roles (name + localized name + description). Replaces the `{{ROLE_*}}` rows.
- **Document-writing template** — "use the default template, or provide your own path?". Default = the canonical bundled one at `"$PLUGIN_ROOT/templates/docs-layer/export-sample-data/Product Document Template.md"` (already copied at init). If the user gives a path, copy that file over `export-sample-data/Product Document Template.md` instead.
- **Brand color** — only meaningful if Docusaurus is installed. A hex color; regenerate the 7 `--ifm-color-primary-*` shades in `src/css/custom.css` from it.

**The 3 init answers (editable here too)**
- **Product name** — updates `{{PRODUCT_NAME}}` everywhere and, if Docusaurus, the title/slug.
- **Documentation language** — re-applies styling: if it changes RTL↔LTR and Docusaurus is present, rewrite the `i18n` block and the `customCss` array (add/remove `custom-rtl.css`), and add/remove the RTL assets (fonts + `custom-rtl.css`). Use `/lore:add-docusaurus`'s asset-copy logic if you need to add RTL assets.
- **Docusaurus on/off** — if currently OFF and the user wants it ON, route to `/lore:add-docusaurus` (do that flow). If currently ON and the user wants it OFF, offer to remove the viewer files (`docusaurus.config.ts`, `sidebars.ts`, `package.json`, `src/`, `static/css`, `static/fonts`, `tsconfig.json`) while keeping `docs/` and `.claude/`.

## Step 2 — Apply

For each setting the user provided (skip the rest), edit the right file:
- Sources, roles, product name/description, language → `.claude/CLAUDE.md`.
- Title/slug/org/copyright, i18n, customCss → `docusaurus.config.ts` / `package.json` (only if Docusaurus present).
- Brand color → `src/css/custom.css`.
- Document template → `export-sample-data/Product Document Template.md`.

**Never write `{{...}}` into any file under `docs/`** (MDX breaks the build). Plain text only there.

## Step 3 — Validate + report

- If Docusaurus is present and you changed config/CSS, run `npm run build` and report green/red.
- Summarize what changed and what was skipped (still unset). Remind the user they can re-run `/lore:config` anytime.
