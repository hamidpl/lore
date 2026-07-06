---
description: Add the Docusaurus viewer (browsable site) to an existing docs-only Lore project by fetching the latest Docusaurus, with RTL styling if the documentation language is right-to-left.
---

# /lore:add-docusaurus — Add the Docusaurus viewer to a docs-only project

The user has a Lore documentation project that is **docs-only** (Markdown in `docs/`, config in `.claude/`, but no `docusaurus.config.ts`). Add the Docusaurus site layer so the docs render as a browsable website. Keep your messages and config in **English**.

The viewer is built by **fetching the latest Docusaurus fresh** with the official scaffolder (`create-docusaurus@latest`) and then overlaying Lore's config, styling, and — for RTL languages — the Persian font/RTL assets. Lore does **not** bundle a pinned Docusaurus version, so every install gets the current release.

## Step 0 — Preconditions

- Resolve the plugin root (env `${CLAUDE_PLUGIN_ROOT}`, else glob `~/.claude/plugins/marketplaces/*/plugins/lore`, else ask — never `$(dirname "$0")`); you need `scripts/scaffold.sh`, `scripts/detect-project.sh`, and the `templates/`.
- **Network is required** for this command (it downloads Docusaurus from npm). If you are offline, stop and tell the user to retry when online.
- Run `sh "$PLUGIN_ROOT/scripts/detect-project.sh"`:
  - `has-docusaurus` → already installed; tell the user and stop.
  - `empty` / `non-empty` (no docs) → suggest `/lore:init` instead and stop.
  - `docs-only` → proceed.

## Step 1 — Determine the language

Read the documentation language / locale from `.claude/CLAUDE.md` (the Content language line and the Locale/Direction line). If it's ambiguous, ask the user (RTL e.g. Persian vs LTR e.g. English). Derive `LOCALE`, `DIRECTION`, `HTML_LANG`, `LANG_LABEL`, and whether the language is RTL.

## Step 2 — Fetch the latest Docusaurus into a temp dir

`create-docusaurus` refuses to scaffold into a non-empty directory and generates its own sample content, so scaffold into a throwaway temp dir — never into `.` (which already holds `docs/` + `.claude/`). Run from the project root:

```bash
rm -rf .lore-tmp
npx --yes create-docusaurus@latest .lore-tmp/site classic --typescript --skip-install
```

`--skip-install` is deliberate: dependencies are installed once at the project root in Step 6 (so `node_modules/` lands in the project, not the temp).

**If this command fails** (e.g. no network): run `rm -rf .lore-tmp`, leave `docs/` and `.claude/` untouched, and tell the user the fetch failed and to retry online. Because nothing is moved until Step 3, a failed fetch leaves the project pristine.

## Step 3 — Import the framework, discard the samples

First delete the parts of the fresh scaffold that Lore replaces or that would clobber the user's docs, then move everything that remains into the project **without overwriting any existing file**:

```bash
# Discard the sample/landing content. The user's own docs/ win; Lore owns
# config/sidebars/css/.gitignore; blog is off; the sample homepage, its component,
# and the sample static images would only add dead code + orphan-image warnings.
rm -rf .lore-tmp/site/docs .lore-tmp/site/blog \
       .lore-tmp/site/src/pages .lore-tmp/site/src/components .lore-tmp/site/src/css/custom.css \
       .lore-tmp/site/static/img \
       .lore-tmp/site/sidebars.ts .lore-tmp/site/docusaurus.config.ts \
       .lore-tmp/site/README.md .lore-tmp/site/.gitignore

# Move the remaining framework files (package.json, tsconfig.json, static/.nojekyll, …)
# into the project root, skipping anything that already exists.
( cd .lore-tmp/site && find . -type f ) | while IFS= read -r rel; do
  rel="${rel#./}"
  if [ -e "./$rel" ]; then
    echo "skip (exists): $rel"
  else
    mkdir -p "$(dirname "./$rel")"
    mv ".lore-tmp/site/$rel" "./$rel"
    echo "moved: $rel"
  fi
done

rm -rf .lore-tmp
```

**Why `src/pages/` MUST be deleted:** Lore sets `routeBasePath: '/'` (docs are the homepage). A surviving `src/pages/index.tsx` produces a *duplicate-route* build error. This deletion is mandatory, not cosmetic. (`src/components/` and the sample `static/img/` images go with it — once the homepage is gone they are orphans.)

## Step 4 — Overlay Lore's config, styling, and (RTL) Persian assets

```bash
sh "$PLUGIN_ROOT/scripts/scaffold.sh" --target . --layer docusaurus   # + --layer rtl if RTL
```

This drops Lore's `docusaurus.config.ts` (templated), `sidebars.ts`, `src/css/custom.css` (the brand styling), and `.gitignore` into the now-empty slots (Step 3 removed the generated equivalents). For an **RTL** language, also pass `--layer rtl` to add `src/css/custom-rtl.css` plus the self-hosted **Vazirmatn** font files. Existing files are never overwritten, so `docs/` and `.claude/` stay intact.

## Step 5 — Fill config + wire the sidebar to existing docs

- `package.json`: `{{PROJECT_SLUG}}`.
- `docusaurus.config.ts`: title/tagline/slug/org/copyright + i18n (`{{LOCALE}}`, `{{LANG_LABEL}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`). Pull product name/description from `.claude/CLAUDE.md`. **RTL:** set `customCss` to `['./src/css/custom.css', './src/css/custom-rtl.css']`; **LTR:** keep `['./src/css/custom.css']`.
- `sidebars.ts`: generate a sidebar that mirrors the **existing** `docs/` tree (one entry per section/folder), not the placeholder example.

## Step 6 — Install, build, and show the user how to preview

Run, **from the project root** (the folder that now contains `package.json`):

```bash
npm install @docusaurus/theme-mermaid && npm run build
```

`@docusaurus/theme-mermaid` powers the user-flow diagrams that `figma-to-doc` / `site-to-doc` emit as ```` ```mermaid ```` fences. Lore's `docusaurus.config.ts` references it in `themes: [...]`, so it **must** be installed or the build fails with "Cannot find module `@docusaurus/theme-mermaid`" — install it explicitly here (the fresh scaffold does not include it). If the build fails on a Node engine error instead, tell the user the installed Docusaurus needs a newer Node (the version is whatever the latest release requires).

After a green build, set `"docusaurus": true` in `.claude/lore.json` (create the marker if a pre-marker project lacks it) so the project state stays accurate.

Then give the user **beginner-friendly** preview guidance. Stress that all commands run **inside the project folder** (the one with `package.json`), and explain each:

- `npm install` — downloads the site's dependencies (needed once, and again after a fresh `git clone`).
- `npm start` — starts the live **dev server** with hot reload at **http://localhost:3000**. Use this while writing docs; stop it with `Ctrl+C`.
- `npm run build` — produces the optimized **production** site in `build/`. This is the check that must pass before delivery (it catches broken links, bad image paths, and MDX errors).
- `npm run serve` — serves the already-built `build/` so you can preview the exact production output (run `npm run build` first).

Note that they can change the brand color or language anytime via `/lore:config`.
