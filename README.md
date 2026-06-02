# Lore — Product Documentation Factory

**Lore** is a [Claude Code plugin](https://code.claude.com/docs/en/plugins) that packages a reusable, product-agnostic **documentation factory**. Install it in any documentation repo and you get the same skills, review subagents, and BLOCKING-rule enforcement hooks — maintained once, consumed everywhere, with zero drift.

This repository is **both** the plugin and its marketplace:

```
lore/
├── .claude-plugin/marketplace.json     # marketplace catalog (name: lore-marketplace)
└── plugins/lore/                        # the plugin (name: lore)
    ├── .claude-plugin/plugin.json
    ├── commands/                        # init, config, add-docusaurus (the scaffold wizard)
    ├── skills/                          # figma-to-doc, brief-to-doc, site-to-doc, doc-reviewer
    ├── agents/                          # doc-validator, figma-extractor (supporting subagents)
    ├── hooks/                           # hooks.json + check-image-path.sh + check-frontmatter.sh + verify-docs.sh
    ├── scripts/                         # detect-project.sh, scaffold.sh (used by the wizard)
    └── templates/                       # docs-layer, docusaurus-base, rtl-assets + skill-template.md
```

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
| Hooks | `hooks/hooks.json` | BLOCKING enforcement: image paths (§6/Rule 1) + frontmatter (§2/§6) |

## Division of responsibility (the golden rule)

Lore carries **only the product-agnostic methodology**. Everything product-specific lives in the **consuming repo's `CLAUDE.md`**:

| Layer | Where it lives |
|-------|----------------|
| Skills, subagents, hooks, skill-authoring template | **This plugin** (changes once, propagates to all repos via `/plugin update`) |
| Definition of Done, image-path rules, general rules | The consuming repo's `CLAUDE.md` (always-on context; a plugin cannot inject always-on context) |
| Trusted sources, user roles, documentation structure, content | The consuming repo (per-product) |

> Skills reference rules by `CLAUDE.md` Section number; they never restate or hard-code a product's sources, roles, or structure. That is the only thing that lets one skill serve every product.

## Install

Installing Lore is **two separate steps** — and a common point of confusion, so read this carefully:

1. **Add the marketplace** (the catalog Lore is published in) — done once per machine.
2. **Install the plugin** from that catalog — also once per machine.

```text
/plugin marketplace add hamidpl/lore       # step 1 — add the catalog
/plugin install lore@lore-marketplace       # step 2 — install the plugin
```

Run all plugin commands **inside Claude Code** (they start with `/`). Both commands are idempotent — re-running `add` when the catalog already exists just succeeds silently.

For a team/CI repo, install at project scope so the repo is self-contained:

```text
/plugin install lore@lore-marketplace --scope project
```

This writes `extraKnownMarketplaces` + `enabledPlugins` into the repo's `.claude/settings.json`, so anyone who clones and trusts the repo gets the plugin automatically.

### Already installed? Enable it in a project

> **Installed ≠ enabled.** Installing caches the plugin on your machine once. *Enabling* turns it on for a specific project. If you already installed Lore before, **do not** run `/plugin install` again (it will error — there's nothing new to install). Instead, just enable it:

**The easy way — interactive menu:**

```text
/plugin
```

Press <kbd>Tab</kbd> to the **Installed** tab → select `lore` → <kbd>Enter</kbd> → **Enable** (for this project). The same menu lets you disable or uninstall, and the **Marketplaces** tab lets you add/update catalogs — all without typing settings by hand.

**The manual way — edit `.claude/settings.json`** in your project root:

```json
{
  "enabledPlugins": {
    "lore@lore-marketplace": true
  }
}
```

Set it to `false` to disable Lore in that project. (Use `~/.claude/settings.json` instead to enable it for *all* your projects.)

### Update to the latest version

When a new Lore release ships, pull it in two steps:

```text
/plugin marketplace update lore-marketplace    # 1. refresh the catalog
```
```bash
claude plugin update lore@lore-marketplace      # 2. update the installed plugin
```

You can also do both from the `/plugin` menu (**Marketplaces** tab → update). To see which version you have, open `/plugin` → **Installed** → `lore`.

### Local development

```text
/plugin marketplace add /absolute/path/to/lore     # local path during development
claude plugin validate ./plugins/lore              # validate before publishing
```

## Setting up a new product documentation repo

The fastest path is the **`/lore:init` wizard** — two steps:

```text
claude plugin install lore@lore-marketplace          # once per machine
cd <your-empty-or-existing-project>
/lore:init                                            # answer 3 questions
```

`/lore:init` asks just 3 essentials (all required): **product name**, **documentation language**, and **install Docusaurus?**. It then generates the documentation layer (`docs/` + `.claude/`) and, if you chose it, a Docusaurus viewer — building a preview. Everything else is optional and deferred to `/lore:config`.

- **Documentation is optional-Docusaurus by design.** Choose **No** and you get only the Markdown docs + `.claude/` config (write docs immediately, decide on output later). Add a browsable site anytime with **`/lore:add-docusaurus`**.
- **Language drives styling.** An RTL language (Persian, Arabic, …) gets the self-hosted Vazirmatn font + right-to-left layout; an LTR language (English, …) gets stock Docusaurus styling. The generated `CLAUDE.md` is language-agnostic — no Persian is hard-coded.
- **Nothing is locked in.** Run **`/lore:config`** anytime to fill or edit the project site URL, product description, trusted sources (§1), the document-writing template, the brand color — and even the 3 init answers (name / language / Docusaurus on-off). All `/lore:config` questions are skippable. (User roles live in §3 of the repo's `CLAUDE.md`; add them by hand if your product needs them.)
- **Non-empty folders are safe.** Running `/lore:init` in an existing project adds only the documentation layer and never overwrites your files.

Then build content with `lore:figma-to-doc` / `lore:brief-to-doc` / `lore:site-to-doc`; validate with `lore:doc-reviewer`; deploy (e.g. Cloudflare Pages: build `npm run build`, output `build`).

## Skill Authoring Standard

Every skill — new or updated — must follow the canonical structure in [`plugins/lore/templates/skill-template.md`](plugins/lore/templates/skill-template.md).

**Golden rule (Rule 4 — Single Place of Truth):** a skill contains ONLY input-specific content. It must NOT restate any global rule (DoD, image paths, user roles, trusted sources, final-report structure) — reference the relevant `CLAUDE.md` Section instead.

**Standard SKILL.md sections (in order):**

1. **When to Use** — trigger and scope
2. **Pre-Flight Checklist** — input-specific source gathering (references `CLAUDE.md` §0/§1)
3. **Core Workflow** — the skill's unique value (the only detailed part)
4. **DoD Additions** — only input-specific deltas (references §4/§6 for the rest)
5. **Final Report Additions** — only skill-specific fields (references §8)
6. **Completion Checklist** — ends with self-verification via the `lore:doc-validator` subagent
7. **Reference Example**

## Versioning

Semantic versioning in `plugins/lore/.claude-plugin/plugin.json`. Bump on every release; consumers upgrade with `/plugin update lore`. Repos can pin a version for controlled rollout.

## Maintenance notes

- **Hook paths** must use `${CLAUDE_PLUGIN_ROOT}` (not `$CLAUDE_PROJECT_DIR/.claude/...`) so they resolve to the installed plugin location.
- **Wizard scripts self-locate.** `scripts/scaffold.sh` and `detect-project.sh` resolve their own plugin root via the script path (`$(dirname "$0")`) rather than relying on `${CLAUDE_PLUGIN_ROOT}` being present in the model's Bash env, which is not guaranteed during command execution.
- **Template layers** live under `templates/`: `docs-layer/` (always), `docusaurus-base/` (optional viewer **overlay** — config + sidebars + custom.css + .gitignore; the Docusaurus framework itself is fetched fresh via `create-docusaurus@latest`), `rtl-assets/` (RTL languages only). The `docs-layer/CLAUDE.md` is the canonical thin product CLAUDE.md and uses `{{...}}` placeholders (including `{{DOC_LANGUAGE}}`/`{{LOCALE}}`) the wizard fills.
- **MDX caveat:** never put `{{...}}` in any file under `docs/` — Docusaurus evaluates `{...}` as JS and the build fails. Placeholders live only in non-MDX files.
- **Subagent references** inside skills use the `lore:` namespace (`lore:doc-validator`, `lore:figma-extractor`).
- The hook scripts operate on the consuming project's `docs/` and `static/img/` via paths relative to the project working directory.
