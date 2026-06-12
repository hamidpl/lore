---
description: Scaffold a new product documentation project (interactive wizard). Asks 3 essentials, generates the docs layer (+ optional Docusaurus viewer), and points you to /lore:config for the rest.
---

# /lore:init — New product documentation wizard

You are running the **Lore init wizard**. Your job: turn the user's current directory into a working product-documentation project with the fewest questions, then hand off to `/lore:config` for the rest.

Keep all generated files and your own messages in **English** (the *documentation content* language is a wizard answer and applies to the docs the user later writes, not to this tooling).

## Step 0 — Locate the plugin scripts

The bundled scripts live under the plugin root. Resolve it in this order (do **not** use `$(dirname "$0")` — when you run a bash block, `$0` is the shell, not this markdown file):

1. If `${CLAUDE_PLUGIN_ROOT}` is set in the environment, use it.
2. Otherwise glob the installed plugin: `ls -d ~/.claude/plugins/marketplaces/*/plugins/lore 2>/dev/null | head -n1`.
3. If neither resolves, ask the user for the plugin path.

You need `"$PLUGIN_ROOT/scripts/detect-project.sh"`, `"$PLUGIN_ROOT/scripts/scaffold.sh"`, and `"$PLUGIN_ROOT/templates/"`.

## Step 1 — Detect the project state

Run `sh "$PLUGIN_ROOT/scripts/detect-project.sh"` in the user's cwd. Branch on the result:

- **`empty`** → full scaffold (proceed normally).
- **`docs-only`** or **`has-docusaurus`** → a documentation project already exists here. Tell the user what's present and offer to **add only the missing documentation layer** (never overwrite). Do NOT re-scaffold Docusaurus if it's already there.
- **`non-empty`** → there are unrelated files here. Explain that `/lore:init` adds a documentation layer (`docs/` + `.claude/`) and, optionally, Docusaurus, and that existing files are never overwritten. Confirm the user wants to proceed in this folder before continuing.

## Step 2 — Ask the 3 essentials (MANDATORY)

Use AskUserQuestion. **All three are required — do not proceed until each is answered.** Give each a one-line explanation.

1. **Product name** — the product these docs are for (used in titles, config, the DoD header).
2. **Documentation language** — the language docs will be *written in*. This drives styling: an RTL language (e.g. Persian, Arabic) gets the self-hosted Vazirmatn font + right-to-left layout; an LTR language (e.g. English) gets stock styling. Offer at least: Persian (RTL), English (LTR), Other.
3. **Install Docusaurus?** — Docusaurus is the optional tool that renders the Markdown docs into a browsable website. **Yes** = fetch the latest Docusaurus and build a preview now (needs network); **No** = create only the documentation files (you can add Docusaurus later with `/lore:add-docusaurus`).

Derive language variables from answer 2:
- RTL language → `LOCALE` (e.g. `fa`), `DIRECTION=rtl`, `HTML_LANG` (e.g. `fa-IR`), `LANG_LABEL` (the language's endonym), and include the `rtl` layer.
- LTR language → `LOCALE` (e.g. `en`), `DIRECTION=ltr`, `HTML_LANG` (e.g. `en-US`), `LANG_LABEL`, no `rtl` layer.
- `DOC_LANGUAGE` = the human language name (e.g. "Persian (Farsi)", "English").

## Step 3 — Scaffold the docs layer

Always scaffold the docs layer first — this is everything a docs-only project needs:

```bash
sh "$PLUGIN_ROOT/scripts/scaffold.sh" --target . --layer docs
```

The Docusaurus viewer (and its RTL assets) is added separately in Step 5, because Lore **fetches the latest Docusaurus** rather than copying a bundled, version-pinned one.

## Step 4 — Fill the essential placeholders (docs layer)

Edit the generated files to replace the essential placeholders only. The optional product-layer sections (§1 Trusted Sources, §3 User Roles, the Documentation Structure) ship as source-agnostic, role-agnostic default text with **no `{{...}}`** — leave them as-is and refine later (`/lore:config` for trusted sources / doc template / etc.; roles you add by hand if your product needs them). After this step, **no `{{...}}` should remain in `.claude/CLAUDE.md`**.

- `.claude/CLAUDE.md`: `{{PRODUCT_NAME}}`, `{{DOC_LANGUAGE}}`, `{{LOCALE}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`.
- `README.md`: `{{PRODUCT_NAME}}` (the project root README scaffolded by the docs layer).
- `docs/intro.md`: rewrite the sample title/body in the chosen documentation language. **Never put `{{...}}` inside any file under `docs/`** — Docusaurus parses it as MDX and the build fails (`{...}` = JS). Use plain text.

### Write the project marker

Write `.claude/lore.json` so later commands (`/lore:config`, `/lore:add-docusaurus`) and `detect-project.sh` can recognize this as a Lore project and read its current settings. Set `docusaurus` to `false` here; Step 5 flips it to `true` if the viewer is installed.

```json
{
  "scaffoldVersion": "<the plugin.json version>",
  "language": "<DOC_LANGUAGE>",
  "locale": "<LOCALE>",
  "direction": "<DIRECTION>",
  "docusaurus": false
}
```

## Step 5 — Add the Docusaurus viewer (only if chosen)

If the user chose **No**, skip this entirely — a docs-only project is complete after Step 4.

If the user chose **Yes**, run the install sequence from **`/lore:add-docusaurus`** (its Steps 2–6) as the single source of truth — Lore fetches the latest Docusaurus, so there is nothing version-pinned to copy:

1. Fetch the latest Docusaurus into `.lore-tmp/` and import the framework, discarding its sample `docs/`/`blog/`/`src/pages/` (add-docusaurus Steps 2–3).
2. Overlay Lore's config/styling: `sh "$PLUGIN_ROOT/scripts/scaffold.sh" --target . --layer docusaurus` — add `--layer rtl` when the language is RTL.
3. Fill the Docusaurus placeholders with the answers you already have: `package.json` `{{PROJECT_SLUG}}` (kebab-case of the product name); `docusaurus.config.ts` `{{SITE_TITLE}}`, `{{SITE_TAGLINE}}`, `{{PROJECT_SLUG}}`, `{{ORG}}`, `{{COPYRIGHT}}`, and the i18n placeholders `{{LOCALE}}`, `{{LANG_LABEL}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`. **RTL:** set `customCss` to `['./src/css/custom.css', './src/css/custom-rtl.css']`; **LTR:** `['./src/css/custom.css']` and ensure no `custom-rtl.css`/fonts were copied.
4. Wire `sidebars.ts` to the real `docs/` tree.
5. Run `npm install && npm run build` from the project root and report green/red.
6. After a green build, set `"docusaurus": true` in `.claude/lore.json`.

Do not duplicate the `create-docusaurus` bash here — follow `/lore:add-docusaurus` for the fetch/import details.

## Step 6 — Finish

Tell the user, in English:
- What was created (docs layer ± Docusaurus, and whether a build passed).
- **Next:** run `/lore:config` to set the project site URL, product description, trusted sources, document-writing template, and brand color (all optional, editable anytime).
- Then use `/lore:figma-to-doc` / `/lore:brief-to-doc` / `/lore:site-to-doc` to write docs, and `/lore:doc-reviewer` to validate.
- If Docusaurus was installed: show the beginner preview guidance from `/lore:add-docusaurus` Step 6 — run commands **inside the project folder**, `npm start` opens the dev server at http://localhost:3000.
- If docs-only: mention `/lore:add-docusaurus` to add a browsable site later.

> The exact wording/order of questions is yours to refine; the rule is: 3 mandatory essentials at init, everything else deferred to `/lore:config`.
