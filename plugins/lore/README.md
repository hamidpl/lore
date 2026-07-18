# Lore — Product Documentation Factory

**Turn designs, briefs, and living products into documentation that lasts.**

[![License](https://img.shields.io/badge/license-MIT-green.svg)](../../LICENSE)
[![Website](https://img.shields.io/badge/website-lorekit.net-ff7a59.svg)](https://lorekit.net)

**Lore** is a [Claude Code plugin](https://code.claude.com/docs/en/plugins) that packages a reusable, product-agnostic **documentation factory**. Install it in any documentation repo to get the same skills, review subagents, and BLOCKING-rule enforcement hooks — maintained once, consumed everywhere.

This directory is the plugin itself. The repository that contains it is also its marketplace.

## What's inside

| Component | Name | Purpose |
|-----------|------|---------|
| Command | `/lore:init` | Scaffold a new docs project (3-question wizard; optional Docusaurus) |
| Command | `/lore:config` | Fill in / edit settings anytime (site URL, sources, template, brand, language) |
| Command | `/lore:add-docusaurus` | Add the Docusaurus viewer to a docs-only project later |
| Skill | `lore:figma-to-doc` | Generate docs from Figma design files |
| Skill | `lore:brief-to-doc` | Generate docs from briefs / PRDs / user stories |
| Skill | `lore:site-to-doc` | Document live product behavior (scenario runner + screenshots) |
| Skill | `lore:doc-reviewer` | Validate docs against the Definition of Done |
| Subagent | `lore:doc-validator` | Read-only DoD validator (run by producer skills before delivery) |
| Subagent | `lore:figma-extractor` | Heavy Figma extraction worker (keeps main context clean) |
| Subagent | `lore:site-explorer` | Heavy live-site exploration worker — drives the browser, captures screenshots |
| Hooks | `hooks/hooks.json` | BLOCKING enforcement of image paths, frontmatter, and tooling references |

## Install and usage

Install, enable, update, and pin instructions — plus the quick start and the full
walkthrough — live in the [repository README](../../README.md).

Guides and the skill reference are on the website: [lorekit.net](https://lorekit.net) ·
[docs.lorekit.net](https://docs.lorekit.net) (EN & FA).

## Contributing

Architecture, authoring rules, and the release checklist live in
[`CLAUDE.md`](../../CLAUDE.md). New or updated skills must follow the canonical
structure in [`templates/skill-template.md`](templates/skill-template.md).

Run the test suite before any change lands:

```bash
sh tests/run-tests.sh          # from the repository root
claude plugin validate ./plugins/lore
```

## License

[MIT](../../LICENSE). The bundled Vazirmatn font is licensed separately under the
SIL Open Font License 1.1 (see
[`templates/rtl-assets/static/fonts/LICENSE-Vazirmatn`](templates/rtl-assets/static/fonts/LICENSE-Vazirmatn)).
