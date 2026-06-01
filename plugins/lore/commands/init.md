---
description: Scaffold a new product documentation project (interactive wizard). Asks 3 essentials, generates the docs layer (+ optional Docusaurus viewer), and points you to /lore:config for the rest.
---

# /lore:init — New product documentation wizard

You are running the **Lore init wizard**. Your job: turn the user's current directory into a working product-documentation project with the fewest questions, then hand off to `/lore:config` for the rest.

Keep all generated files and your own messages in **English** (the *documentation content* language is a wizard answer and applies to the docs the user later writes, not to this tooling).

## Step 0 — Locate the plugin scripts

The bundled scripts live next to this command, under the plugin root. Resolve the plugin root and keep it in a variable, e.g.:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
# Fallback if the env var is not set: this command file is at <root>/commands/init.md
[ -z "$PLUGIN_ROOT" ] && PLUGIN_ROOT="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
```

If you cannot resolve it from the env, find the installed plugin by globbing `~/.claude/plugins/marketplaces/*/plugins/lore` and use `scripts/` + `templates/` under it. You need `"$PLUGIN_ROOT/scripts/detect-project.sh"` and `"$PLUGIN_ROOT/scripts/scaffold.sh"`.

## Step 1 — Detect the project state

Run `sh "$PLUGIN_ROOT/scripts/detect-project.sh"` in the user's cwd. Branch on the result:

- **`empty`** → full scaffold (proceed normally).
- **`docs-only`** or **`has-docusaurus`** → a documentation project already exists here. Tell the user what's present and offer to **add only the missing documentation layer** (never overwrite). Do NOT re-scaffold Docusaurus if it's already there.
- **`non-empty`** → there are unrelated files here. Explain that `/lore:init` adds a documentation layer (`docs/` + `.claude/`) and, optionally, Docusaurus, and that existing files are never overwritten. Confirm the user wants to proceed in this folder before continuing.

## Step 2 — Ask the 3 essentials (MANDATORY)

Use AskUserQuestion. **All three are required — do not proceed until each is answered.** Give each a one-line explanation.

1. **Product name** — the product these docs are for (used in titles, config, the DoD header).
2. **Documentation language** — the language docs will be *written in*. This drives styling: an RTL language (e.g. Persian, Arabic) gets the bundled RTL/Persian fonts + right-to-left layout; an LTR language (e.g. English) gets stock styling. Offer at least: Persian (RTL), English (LTR), Other.
3. **Install Docusaurus?** — Docusaurus is the optional tool that renders the Markdown docs into a browsable website. **Yes** = copy the site files and build a preview now; **No** = create only the documentation files (you can add Docusaurus later with `/lore:add-docusaurus`).

Derive language variables from answer 2:
- RTL language → `LOCALE` (e.g. `fa`), `DIRECTION=rtl`, `HTML_LANG` (e.g. `fa-IR`), `LANG_LABEL` (the language's endonym), and include the `rtl` layer.
- LTR language → `LOCALE` (e.g. `en`), `DIRECTION=ltr`, `HTML_LANG` (e.g. `en-US`), `LANG_LABEL`, no `rtl` layer.
- `DOC_LANGUAGE` = the human language name (e.g. "Persian (Farsi)", "English").

## Step 3 — Scaffold the chosen layers

Call scaffold with the layers implied by the answers (always `docs`; add `docusaurus` if chosen; add `rtl` only if the language is RTL **and** Docusaurus was chosen — RTL assets are CSS/fonts that only matter with the viewer):

```bash
sh "$PLUGIN_ROOT/scripts/scaffold.sh" --target . --layer docs [--layer docusaurus] [--layer rtl]
```

## Step 4 — Fill the essential placeholders

Edit the generated files to replace the essentials only (leave the rest as `{{...}}` for `/lore:config`):

- `.claude/CLAUDE.md`: `{{PRODUCT_NAME}}`, `{{DOC_LANGUAGE}}`, `{{LOCALE}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`.
- `docs/intro.md`: rewrite the sample title/body in the chosen documentation language. **Never put `{{...}}` inside any file under `docs/`** — Docusaurus parses it as MDX and the build fails (`{...}` = JS). Use plain text.
- If Docusaurus was installed:
  - `package.json`: `{{PROJECT_SLUG}}` (kebab-case of the product name).
  - `docusaurus.config.ts`: `{{SITE_TITLE}}`, `{{SITE_TAGLINE}}`, `{{PROJECT_SLUG}}`, `{{ORG}}`, `{{COPYRIGHT}}`, and the i18n placeholders `{{LOCALE}}`, `{{LANG_LABEL}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`.
  - **RTL only:** set `customCss` to the array `['./src/css/custom.css', './src/css/custom-rtl.css']`. **LTR:** leave it as `['./src/css/custom.css']` and ensure no `custom-rtl.css`/fonts were copied.

## Step 5 — Build (only if Docusaurus)

If Docusaurus was installed, run `npm install && npm run build` and report success/failure. If it's docs-only, skip the build entirely.

## Step 6 — Finish

Tell the user, in English:
- What was created (layers + whether a build passed).
- **Next:** run `/lore:config` to set the product description, trusted sources, user roles, document-writing template, and brand color (all optional, editable anytime).
- Then use `/lore:figma-to-doc` / `/lore:brief-to-doc` / `/lore:site-to-doc` to write docs, and `/lore:documentation-reviewer` to validate.
- If docs-only: mention `/lore:add-docusaurus` to add a browsable site later.

> The exact wording/order of questions is yours to refine; the rule is: 3 mandatory essentials at init, everything else deferred to `/lore:config`.
