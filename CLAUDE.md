# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lore is a Claude Code plugin that packages a reusable, product-agnostic documentation factory. This repository serves dual roles: the **plugin** (`plugins/lore/`) and its **marketplace** (`.claude-plugin/marketplace.json`). Consumers install the plugin in their own documentation repos to get skills, review subagents, and BLOCKING-rule enforcement hooks — maintained here once, consumed everywhere.

Current version: check `plugins/lore/.claude-plugin/plugin.json`.

## Repository Layout

```
.claude-plugin/marketplace.json    # marketplace catalog (name: lore-marketplace)
plugins/lore/                      # the plugin itself
  .claude-plugin/plugin.json       # plugin manifest (name, version, description)
  commands/                        # /lore:init, /lore:config, /lore:add-docusaurus
  skills/                          # figma-to-doc, brief-to-doc, site-to-doc, documentation-reviewer
  agents/                          # doc-reviewer, figma-extractor (read-only subagents)
  hooks/                           # hooks.json + 3 shell scripts (BLOCKING enforcement)
  scripts/                         # scaffold.sh, detect-project.sh (self-locating)
  templates/                       # docs-layer, docusaurus-base, rtl-assets, skill-template.md
```

## Commands

**Validate the plugin:**
```bash
claude plugin validate ./plugins/lore --strict
```

**Local dev install (marketplace from local path):**
```bash
/plugin marketplace add /absolute/path/to/lore
```

**End-user install (from GitHub):**
```bash
/plugin marketplace add hamidpl/lore
/plugin install lore@lore-marketplace
```

The Docusaurus template (used by consuming projects, not this repo) uses:
```bash
npm install && npm start     # dev server at localhost:3000
npm run build                # production build (must pass before delivery)
```

## Architecture: The Division of Responsibility

This is the core design principle — every decision flows from it:

| Layer | Lives in | Changes how |
|-------|----------|-------------|
| Product-agnostic methodology (skills, subagents, hooks, templates) | **This plugin** | Changed here once → propagates via `/plugin update` |
| Product-specific rules (DoD, trusted sources, user roles, structure) | Consuming repo's `.claude/CLAUDE.md` | Per-product; plugin cannot inject always-on context |

Skills reference the consuming repo's `CLAUDE.md` rules by **section number** (e.g., "per §6") — they never restate or hard-code product-specific content.

## Rule 4: Single Place of Truth (BLOCKING)

Every fact exists in exactly one canonical location; everywhere else references it. This is the most important authoring constraint:

| Fact category | Canonical location |
|---------------|--------------------|
| Global rules / DoD | Consuming repo's `.claude/CLAUDE.md` |
| Input-specific workflow | The relevant skill (`skills/{name}/SKILL.md`) |
| Lessons learned | Consuming repo's `.claude/lesson-learned.md` |
| Document structure template | `templates/docs-layer/export-sample-data/Product Document Template.md` |
| Skill structure template | `templates/skill-template.md` |

Copying the full text of an existing rule into a second place is prohibited.

## Skill Authoring

All skills follow the canonical 7-section structure defined in `plugins/lore/templates/skill-template.md`:

1. When to Use
2. Pre-Flight Checklist (references CLAUDE.md §0/§1 — only input-specific steps here)
3. Core Workflow (the unique value — only input-specific content)
4. DoD Additions (input-specific deltas only — references §4/§6 for the rest)
5. Final Report Additions (skill-specific fields only — references §8)
6. Completion Checklist (ends with self-verification via `lore:doc-reviewer`)
7. Reference Example

A skill must contain ONLY input-specific content. If something is already a global rule in CLAUDE.md, reference it — don't repeat it.

## Hook System

Three hooks in `plugins/lore/hooks/hooks.json`:

- **`check-image-path.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): images must be in `static/img/`, markdown refs must use `/img/` (never `/static/img/`), images must never be placed in `docs/`.
- **`check-frontmatter.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): every `docs/` markdown must have YAML frontmatter with 4 keys: `sidebar_position`, `title`, `description`, `tags`.
- **`verify-docs.sh`** (Stop, non-blocking): warns about orphan images and bad refs.

**Scope carve-out:** hooks skip `.claude/`, `templates/`, and `_templates/` paths (intentional examples live there).

Hook paths in `hooks.json` use `${CLAUDE_PLUGIN_ROOT}`. Scripts themselves self-locate via `$(dirname "$0")` because `${CLAUDE_PLUGIN_ROOT}` is not guaranteed in the model's Bash environment during command execution.

## Template Layer System

Three independent, composable layers copied by `scripts/scaffold.sh`:

- **`docs-layer`** — always included: `.claude/` (CLAUDE.md, settings.json, lesson-learned.md), `docs/`, `export-sample-data/`
- **`docusaurus-base`** — optional viewer: package.json, docusaurus.config.ts, sidebars.ts, src/css/
- **`rtl-assets`** — optional: Persian fonts (Iran Sans) + right-to-left CSS (only when Docusaurus chosen AND language is RTL)

`scaffold.sh` never overwrites existing files (safe to re-run). Placeholder filling (`{{PRODUCT_NAME}}`, `{{LOCALE}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`, `{{DOC_LANGUAGE}}`) is the command's responsibility, not the script's.

**MDX caveat:** never put `{{...}}` in files under `docs/` — Docusaurus evaluates `{...}` as JavaScript and the build fails. Placeholders live only in config/template files.

## Subagent Naming

All subagent and skill references use the `lore:` namespace prefix: `lore:doc-reviewer`, `lore:figma-extractor`, `lore:figma-to-doc`, etc.

## Versioning

Semantic versioning in `plugins/lore/.claude-plugin/plugin.json`. Bump on every release. Consumers upgrade with `/plugin update lore`.
