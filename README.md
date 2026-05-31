# Lore — Product Documentation Factory

**Lore** is a [Claude Code plugin](https://code.claude.com/docs/en/plugins) that packages a reusable, product-agnostic **documentation factory**. Install it in any documentation repo and you get the same skills, review subagents, and BLOCKING-rule enforcement hooks — maintained once, consumed everywhere, with zero drift.

This repository is **both** the plugin and its marketplace:

```
lore/
├── .claude-plugin/marketplace.json     # marketplace catalog (name: lore-marketplace)
└── plugins/lore/                        # the plugin (name: lore)
    ├── .claude-plugin/plugin.json
    ├── skills/                          # figma-to-doc, brief-to-doc, site-to-doc, documentation-reviewer
    ├── agents/                          # doc-reviewer, figma-extractor (supporting subagents)
    ├── hooks/                           # hooks.json + check-image-path.sh + verify-docs.sh
    └── templates/skill-template.md      # canonical skill-authoring structure
```

## What's inside

| Component | Name | Purpose |
|-----------|------|---------|
| Skill | `lore:figma-to-doc` | Generate docs from Figma design files |
| Skill | `lore:brief-to-doc` | Generate docs from briefs / PRDs / user stories |
| Skill | `lore:site-to-doc` | Document live product behavior |
| Skill | `lore:documentation-reviewer` | Validate docs against the Definition of Done |
| Subagent | `lore:doc-reviewer` | Read-only DoD validator (run by producer skills before delivery) |
| Subagent | `lore:figma-extractor` | Heavy Figma extraction worker (keeps main context clean) |
| Hooks | `hooks/hooks.json` | Deterministic enforcement of BLOCKING image-path rules |

## Division of responsibility (the golden rule)

Lore carries **only the product-agnostic methodology**. Everything product-specific lives in the **consuming repo's `CLAUDE.md`**:

| Layer | Where it lives |
|-------|----------------|
| Skills, subagents, hooks, skill-authoring template | **This plugin** (changes once, propagates to all repos via `/plugin update`) |
| Definition of Done, image-path rules, general rules | The consuming repo's `CLAUDE.md` (always-on context; a plugin cannot inject always-on context) |
| Trusted sources, user roles, documentation structure, content | The consuming repo (per-product) |

> Skills reference rules by `CLAUDE.md` Section number; they never restate or hard-code a product's sources, roles, or structure. That is the only thing that lets one skill serve every product.

## Install

```text
/plugin marketplace add hamidpl/lore
/plugin install lore@lore-marketplace
```

For a team/CI repo, install at project scope so the repo is self-contained:

```text
/plugin install lore@lore-marketplace --scope project
```

This writes `extraKnownMarketplaces` + `enabledPlugins` into the repo's `.claude/settings.json`, so anyone who clones and trusts the repo gets the plugin automatically.

### Local development

```text
/plugin marketplace add /absolute/path/to/lore     # local path during development
claude plugin validate ./plugins/lore --strict     # validate before publishing
```

## Setting up a new product documentation repo

1. Create the docs repo (a Docusaurus site, or — in future — from the `docusaurus-fa-starter` template).
2. Install the plugin at project scope (see above).
3. In that repo's `.claude/CLAUDE.md`, fill the **product layer**: trusted sources (§1), user roles (§3), and documentation structure / sidebar. Keep the general layer (DoD + image-path + general rules) as-is.
4. Build content with `lore:figma-to-doc` / `lore:brief-to-doc` / `lore:site-to-doc`; validate with `lore:documentation-reviewer`.
5. Deploy (e.g. Cloudflare Pages: build `npm run build`, output `build`).

## Skill Authoring Standard

Every skill — new or updated — must follow the canonical structure in [`plugins/lore/templates/skill-template.md`](plugins/lore/templates/skill-template.md).

**Golden rule (Rule 4 — Single Place of Truth):** a skill contains ONLY input-specific content. It must NOT restate any global rule (DoD, image paths, user roles, trusted sources, final-report structure) — reference the relevant `CLAUDE.md` Section instead.

**Standard SKILL.md sections (in order):**

1. **When to Use** — trigger and scope
2. **Pre-Flight Checklist** — input-specific source gathering (references `CLAUDE.md` §0/§1)
3. **Core Workflow** — the skill's unique value (the only detailed part)
4. **DoD Additions** — only input-specific deltas (references §4/§6 for the rest)
5. **Final Report Additions** — only skill-specific fields (references §8)
6. **Completion Checklist** — ends with self-verification via the `lore:doc-reviewer` subagent
7. **Reference Example**

## Versioning

Semantic versioning in `plugins/lore/.claude-plugin/plugin.json`. Bump on every release; consumers upgrade with `/plugin update lore`. Repos can pin a version for controlled rollout.

## Maintenance notes

- **Hook paths** must use `${CLAUDE_PLUGIN_ROOT}` (not `$CLAUDE_PROJECT_DIR/.claude/...`) so they resolve to the installed plugin location.
- **Subagent references** inside skills use the `lore:` namespace (`lore:doc-reviewer`, `lore:figma-extractor`).
- The hook scripts operate on the consuming project's `docs/` and `static/img/` via paths relative to the project working directory.
