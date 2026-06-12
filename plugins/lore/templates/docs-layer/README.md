# {{PRODUCT_NAME}} Documentation

Product documentation for **{{PRODUCT_NAME}}**, written for the product team.

The authoring rules, Definition of Done, trusted sources, and structure live in
[`.claude/CLAUDE.md`](.claude/CLAUDE.md) — start there.

## Writing docs

Use the [Lore](https://github.com/hamidpl/lore) plugin skills:

- `lore:figma-to-doc` — from Figma design files
- `lore:brief-to-doc` — from a brief / PRD / user story
- `lore:site-to-doc` — from observing the live product
- `lore:doc-reviewer` — validate against the Definition of Done

Run `/lore:config` anytime to change settings (site URL, sources, template, brand color, language).

## Previewing the site

> Only if the Docusaurus viewer is installed (this project has a `package.json`).
> A docs-only project is just Markdown under `docs/` — add a viewer later with `/lore:add-docusaurus`.

```bash
npm install      # once (and after a fresh git clone)
npm start        # dev server with hot reload at http://localhost:3000
npm run build    # production build in build/ — must pass before delivery
```
