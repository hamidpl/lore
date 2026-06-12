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
  skills/                          # figma-to-doc, brief-to-doc, site-to-doc, doc-reviewer
  agents/                          # doc-validator, figma-extractor, site-explorer (worker subagents)
  hooks/                           # hooks.json + 4 shell scripts (BLOCKING enforcement)
  scripts/                         # scaffold.sh, detect-project.sh (self-locating)
  templates/                       # docs-layer, docusaurus-base, rtl-assets, skill-template.md
tests/run-tests.sh                 # POSIX hook/script test harness (run before release)
.github/workflows/ci.yml           # shellcheck + manifest + hook tests + scaffold smoke
CHANGELOG.md                       # release notes (tagged vX.Y.Z)
LICENSE                            # MIT (Vazirmatn font: separate OFL notice)
```

## Commands

**Validate the plugin:**
```bash
claude plugin validate ./plugins/lore
```

**Run the test suite (before any release):**
```bash
sh tests/run-tests.sh
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
| Document structure template | `templates/docs-layer/docs-template/Product Document Template.md` |
| Skill structure template | `templates/skill-template.md` |

Copying the full text of an existing rule into a second place is prohibited.

## Skill Authoring

All skills follow the canonical 7-section structure defined in `plugins/lore/templates/skill-template.md`:

1. When to Use
2. Pre-Flight Checklist (references CLAUDE.md §0/§1 — only input-specific steps here)
3. Core Workflow (the unique value — only input-specific content)
4. DoD Additions (input-specific deltas only — references §4/§6 for the rest)
5. Final Report Additions (skill-specific fields only — references §8)
6. Completion Checklist (ends with self-verification via `lore:doc-validator`)
7. Reference Example

A skill must contain ONLY input-specific content. If something is already a global rule in CLAUDE.md, reference it — don't repeat it.

## Hook System

Three hooks in `plugins/lore/hooks/hooks.json`:

- **`check-image-path.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): images must be in `static/img/`, markdown/MDX refs must use `/img/` (never `/static/img/`), images must never be placed in `docs/`.
- **`check-frontmatter.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): every `docs/` markdown/MDX must have a closed YAML frontmatter block with 4 keys: `sidebar_position`, `title`, `description`, `tags` (tolerant of CRLF/BOM).
- **`check-no-tooling-refs.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): `docs/` markdown/MDX must not reference the authoring tooling — blocks `.claude/` paths, `CLAUDE.md` citations, and the `lore:` skill/subagent namespace (Rule 5 / §6). `lore:` requires a non-alphanumeric boundary so prose like "folklore:" is not a false positive.
- **`verify-docs.sh`** (Stop): BLOCKS (exit 2) on images under `docs/` and `/static/img/` refs; WARNS about orphan images. Honors `stop_hook_active` to avoid loops.

**Path scoping:** hooks resolve each file relative to the project root (`$CLAUDE_PROJECT_DIR`, else payload `cwd`) and act only on `docs/` paths. **Scope carve-out:** `.claude/`, `templates/`, and `_templates/` are skipped (intentional examples live there). JSON parsing falls back jq → python3 → sed and warns loudly if none is available rather than silently passing.

Hook paths in `hooks.json` use `${CLAUDE_PLUGIN_ROOT}`. The wizard *scripts* self-locate via `$(dirname "$0")`; the command *markdown* files must not (there `$0` is the shell) — they resolve the root via `${CLAUDE_PLUGIN_ROOT}` → glob → ask.

The hooks are covered by `tests/run-tests.sh` and CI (`.github/workflows/ci.yml`) — run `sh tests/run-tests.sh` after changing any hook or script.

## Template Layer System

Three independent, composable layers copied by `scripts/scaffold.sh`:

- **`docs-layer`** — always included: `.claude/` (CLAUDE.md, settings.json, lesson-learned.md), `docs/`, `docs-template/`, project `README.md`
- **`docusaurus-base`** — optional viewer **overlay**: docusaurus.config.ts, sidebars.ts, src/css/custom.css, .gitignore. The Docusaurus framework itself is fetched fresh via `create-docusaurus@latest` (always latest) by `/lore:add-docusaurus`, not bundled here.
- **`rtl-assets`** — optional: Persian font (self-hosted Vazirmatn `@font-face` with webpack-relative URLs inside `custom-rtl.css`) + right-to-left CSS (only when Docusaurus chosen AND language is RTL)

`scaffold.sh` never overwrites existing files (safe to re-run). Placeholder filling (`{{PRODUCT_NAME}}`, `{{LOCALE}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`, `{{DOC_LANGUAGE}}`) is the command's responsibility, not the script's.

**MDX caveat:** never put `{{...}}` in files under `docs/` — Docusaurus evaluates `{...}` as JavaScript and the build fails. Placeholders live only in config/template files.

## Subagent Naming

All subagent and skill references use the `lore:` namespace prefix: `lore:doc-validator`, `lore:figma-extractor`, `lore:site-explorer`, `lore:figma-to-doc`, etc.

## Versioning

Semantic versioning in `plugins/lore/.claude-plugin/plugin.json`. The release checklist for every version:

1. Bump the version in `plugins/lore/.claude-plugin/plugin.json`.
2. Record the changes under a new `## X.Y.Z` section in `CHANGELOG.md`.
3. Tag the release: annotated `vX.Y.Z` (`git tag -a vX.Y.Z -m "vX.Y.Z — <summary>"`), matching the existing tag style.
4. **Publish a GitHub Release** for the tag, using that version's `CHANGELOG.md` section as the notes (`gh release create vX.Y.Z --title "Lore vX.Y.Z" --notes-file <section> --latest`). Every tag should have a corresponding published Release.

The README is the single source of truth for consumer install/update/pin commands — don't restate them here (Rule 4).
