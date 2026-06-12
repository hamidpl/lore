# Lore — Product Documentation Factory

> **Status: beta (pre-1.0).** Lore works end-to-end, but commands, templates, and conventions may still change before `1.0.0`. Pin to a git tag if you need stability (see [Versioning](#versioning)).

**Lore** is a [Claude Code plugin](https://code.claude.com/docs/en/plugins) that packages a reusable, product-agnostic **documentation factory**. Install it in any documentation repo to get the same skills, review subagents, and BLOCKING-rule enforcement hooks — maintained once, consumed everywhere.

This single repo is **both** the plugin (`plugins/lore/`) and its marketplace (`.claude-plugin/marketplace.json`).

## What's inside

| Component | Name | Purpose |
|-----------|------|---------|
| Command | `/lore:init` | Scaffold a new docs project (3-question wizard; optional Docusaurus) |
| Command | `/lore:config` | Fill in / edit settings anytime (site URL, sources, template, brand, language) |
| Command | `/lore:add-docusaurus` | Add the Docusaurus viewer to a docs-only project later |
| Skill | `lore:figma-to-doc` | Generate docs from Figma design files |
| Skill | `lore:brief-to-doc` | Generate docs from briefs / PRDs / user stories |
| Skill | `lore:site-to-doc` | Document live product behavior |
| Skill | `lore:doc-reviewer` | Validate docs against the Definition of Done |
| Subagent | `lore:doc-validator` | Read-only DoD validator (run by producer skills before delivery) |
| Subagent | `lore:figma-extractor` | Heavy Figma extraction worker (keeps main context clean) |
| Hooks | `hooks/hooks.json` | BLOCKING enforcement of image paths and frontmatter |

## Install

Installing is two steps, run **inside Claude Code** (both are idempotent):

```text
/plugin marketplace add hamidpl/lore       # 1. add the catalog
/plugin install lore@lore-marketplace       # 2. install the plugin
```

For a team/CI repo, install at project scope so a clone is self-contained:

```text
/plugin install lore@lore-marketplace --scope project
```

**Installed ≠ enabled.** Installing caches the plugin on your machine; *enabling* turns it on for a project. If Lore is already installed, don't run `install` again — just enable it via the `/plugin` menu (**Installed** tab → `lore` → Enable), or add to your project's `.claude/settings.json`:

```json
{ "enabledPlugins": { "lore@lore-marketplace": true } }
```

**Update** when a new release ships:

```text
/plugin marketplace update lore-marketplace     # refresh the catalog
claude plugin update lore@lore-marketplace       # update the plugin
```

## Quick start

```text
cd <your-empty-or-existing-project>
/lore:init                                  # answer 3 questions
```

`/lore:init` asks 3 essentials — **product name**, **documentation language**, **install Docusaurus?** — then scaffolds the docs layer (`docs/` + `.claude/`) and, if chosen, a Docusaurus viewer.

- **Docusaurus is optional.** Choose **No** for Markdown-only docs and add a browsable site later with `/lore:add-docusaurus`.
- **Language drives styling.** An RTL language (Persian, Arabic, …) gets the self-hosted Vazirmatn font + right-to-left layout; LTR languages get stock Docusaurus styling.
- **Nothing is locked in.** Run `/lore:config` anytime to edit the site URL, product description, trusted sources, doc template, brand color — even the 3 init answers.
- **Safe in existing repos.** `/lore:init` only adds the documentation layer and never overwrites your files.

Then build content with `lore:figma-to-doc` / `lore:brief-to-doc` / `lore:site-to-doc`, validate with `lore:doc-reviewer`, and deploy the static `build/` output to any host.

## Division of responsibility (the golden rule)

Lore carries **only the product-agnostic methodology**. Everything product-specific lives in the **consuming repo's `CLAUDE.md`**:

| Layer | Where it lives |
|-------|----------------|
| Skills, subagents, hooks, authoring template | **This plugin** — change once, propagate to every repo via `/plugin update` |
| Definition of Done, image-path rules, trusted sources, user roles, structure | The **consuming repo's `CLAUDE.md`** (per-product) |

Skills reference rules by `CLAUDE.md` section number — they never restate or hard-code a product's sources, roles, or structure. That is what lets one skill serve every product.

> New or updated skills must follow the canonical structure in [`plugins/lore/templates/skill-template.md`](plugins/lore/templates/skill-template.md). Contributor and maintenance details live in [`CLAUDE.md`](CLAUDE.md).

## Versioning

Lore uses [semantic versioning](https://semver.org); the current version lives in [`plugins/lore/.claude-plugin/plugin.json`](plugins/lore/.claude-plugin/plugin.json) and changes are recorded in [CHANGELOG.md](CHANGELOG.md). It is **pre-1.0**, so minor releases may include breaking changes until `1.0.0`. To pin a version, add the marketplace at a fixed git tag — e.g. `/plugin marketplace add hamidpl/lore#v0.1.0`.

> **Security note:** Lore ships hooks that run shell scripts automatically in your repo. Review plugin updates the way you would any dependency bump.

## License

[MIT](LICENSE). The bundled Vazirmatn font is licensed separately under the SIL Open Font License 1.1 (see [`plugins/lore/templates/rtl-assets/static/fonts/LICENSE-Vazirmatn`](plugins/lore/templates/rtl-assets/static/fonts/LICENSE-Vazirmatn)).
