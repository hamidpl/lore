---
description: Fill in or edit a Lore documentation project's settings — project site URL, product description, trusted sources, doc-writing template, brand color, and the 3 init answers. All questions are skippable.
---

# /lore:config — Configure / edit documentation settings

You configure an existing Lore documentation project (one created by `/lore:init`). You both **fill in** values left as placeholders and **edit** values set earlier. Run anytime; it is idempotent. Keep your messages and the config files in **English** (the documentation *content* language is one of the settings below).

## Step 0 — Confirm context

Ensure `.claude/CLAUDE.md` exists in the cwd (this is a Lore project). If not, tell the user to run `/lore:init` first and stop.

Read `.claude/lore.json` for the project's current settings (language, locale, direction, docusaurus on/off, scaffoldVersion). If the file is missing (a pre-marker project), reconstruct it from the current state — language/locale/direction from `.claude/CLAUDE.md`, `docusaurus` from whether `docusaurus.config.*` exists — and write it, so subsequent runs have a single source of truth for these values.

Resolve the plugin root the same way as `/lore:init` (env `${CLAUDE_PLUGIN_ROOT}`, else glob `~/.claude/plugins/marketplaces/*/plugins/lore`, else ask) — never `$(dirname "$0")` — in case you need the bundled document template.

## Step 1 — Ask which settings to set (ALL skippable)

Use AskUserQuestion. Every question is optional: tell the user they can **skip** any item and it keeps its current value. Show the current value where one is already set. Cover:

**Deferred settings**
- **Project site URL** — the product's live website, if it has one (optional). Ask this **before** the description. If given, record it together with the product description and offer to add it to §1 Trusted Sources as the live product URL.
- **Product description** — a short description of the product. It is the canonical source (Rule 4) for three surfaces written in Step 2: the **Product Overview — PRODUCT LAYER** block in `.claude/CLAUDE.md`, the **`docs/intro.md`** home page (expanded into a real introduction), and the Docusaurus **tagline** when Docusaurus is present.
- **Trusted sources (§1)** — e.g. a Help Center URL, Blog URL, Live product URL, or any source the user trusts. These become the configured trusted sources in the DoD. Replace the "Configured trusted sources" block in §1 (default text: "_None yet…_") with the list the user gives.
- **Document-writing template** — present exactly **two** options: **Use the default template** (the canonical bundled one at `"$PLUGIN_ROOT/templates/docs-layer/templates/product-document-template.md"`, already copied at init) or **Provide a custom template path**. If the user picks custom, capture the path (free-text) and copy that file over `templates/product-document-template.md`.
- **Brand color** — only meaningful if Docusaurus is installed. A hex color; regenerate the 7 `--ifm-color-primary-*` shades in `src/css/custom.css` from it.

**The 3 init answers (editable here too)**
- **Product name** — updates `{{PRODUCT_NAME}}` everywhere and, if Docusaurus, the title/slug.
- **Documentation language** — re-applies styling: if it changes RTL↔LTR and Docusaurus is present, rewrite the `i18n` block and the `customCss` array (add/remove `custom-rtl.css`), and add/remove the RTL assets (fonts + `custom-rtl.css`). Use `/lore:add-docusaurus`'s asset-copy logic if you need to add RTL assets.
- **Docusaurus on/off** — if currently OFF and the user wants it ON, route to `/lore:add-docusaurus` (do that flow). If currently ON and the user wants it OFF, offer to remove the viewer files (`docusaurus.config.ts`, `sidebars.ts`, `package.json`, `package-lock.json`, `tsconfig.json`, `babel.config.js`, `src/`, `static/fonts`, `node_modules/`, `build/`, `.docusaurus/`) while keeping `docs/`, `static/img/`, and `.claude/`.

## Step 2 — Apply

For each setting the user provided (skip the rest), edit the right file. §1 contains default source-agnostic text, not `{{...}}` tokens — **rewrite the whole section** with the user's values rather than looking for placeholders to substitute:
- Site URL, sources, product name/language → `.claude/CLAUDE.md`.
- Title/slug/org/copyright, i18n, customCss → `docusaurus.config.ts` / `package.json` (only if Docusaurus present). When re-writing the footer `copyright` line, **keep the trailing ` · <Lore attribution>`** intact (the "ساخته شده با Lore" / "Built with Lore" link) — don't drop it.
- Brand color → `src/css/custom.css`.
- Document template → `templates/product-document-template.md`.

**Product description → three derived surfaces** (only when the user gave/changed a description):
1. **`.claude/CLAUDE.md`** — rewrite the default line in the **Product Overview — PRODUCT LAYER** block with the one/two-sentence description (the canonical copy, Rule 4).
2. **`docs/intro.md`** — expand the description into a real home page: a fitting title and a short introduction, in the documentation language, from the product name + description (you may also summarize the sections already present under `docs/`). This replaces the sample starter body.
3. **Docusaurus `tagline`** — set it from the same description (only if Docusaurus is present).

**Never write `{{...}}` into any file under `docs/`** (MDX breaks the build) — `docs/intro.md` is plain text only.

## Step 3 — Sync the marker, validate + report

- If you changed the language, locale, direction, or Docusaurus on/off, update the matching fields in `.claude/lore.json`.
- If Docusaurus is present and you changed config/CSS, run `npm run build` and report green/red.
- Summarize what changed and what was skipped (still unset). Remind the user they can re-run `/lore:config` anytime.
