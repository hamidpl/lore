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
  hooks/                           # hooks.json + 5 shell scripts (BLOCKING enforcement + methodology sync)
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
| Product-agnostic methodology (skills, subagents, hooks, templates) + the always-on rules (General Rules, DoD §0/§2/§4–§8) | **This plugin** | Changed here once → propagates via `/plugin update` |
| Product-specific data (trusted sources §1, user roles §3, product overview, structure) | Consuming repo's `.claude/CLAUDE.md` | Per-product; the user owns and edits it |

Skills reference DoD rules by **section number** (e.g., "per §6") — the numbers are unique across the two files, so they resolve regardless of which file a section lives in. Skills never restate or hard-code product-specific content.

**The always-on rules propagate via a synced file (as of v0.6.0).** The methodology (General Rules + DoD §0/§2/§4–§8) lives in a plugin-owned file `templates/docs-layer/.claude/lore-methodology.md`. A consuming repo gets a thin `.claude/CLAUDE.md` (product layer + custom rules) that `@`-imports it. The `SessionStart` sync hook (`hooks/sync-lore-files.sh`) copies the latest methodology file into the repo on `/plugin update` — so rule improvements reach existing projects automatically, which a plugin otherwise cannot do (it cannot inject always-on context directly). Only §1/§3 (product-layer DoD sections) stay in the repo's `CLAUDE.md`, with stub pointers in the methodology file so the §-numbering reads continuously.

## Rule 4: Single Place of Truth (BLOCKING)

Every fact exists in exactly one canonical location; everywhere else references it. This is the most important authoring constraint:

| Fact category | Canonical location |
|---------------|--------------------|
| Methodology: General Rules + DoD §0/§2/§4–§8 | `templates/docs-layer/.claude/lore-methodology.md` (plugin-owned; synced into each repo) |
| Product-layer DoD: trusted sources §1, user roles §3 | Consuming repo's `.claude/CLAUDE.md` |
| Input-specific workflow | The relevant skill (`skills/{name}/SKILL.md`) |
| Lessons learned | Consuming repo's `.claude/lesson-learned.md` |
| Document structure template | `templates/docs-layer/templates/product-document-template.md` |
| Skill structure template | `templates/skill-template.md` |

Copying the full text of an existing rule into a second place is prohibited.

## Skill Authoring

All skills follow the canonical 7-section structure defined in `plugins/lore/templates/skill-template.md`:

1. When to Use
2. Pre-Flight Checklist (references §0/§1 — only input-specific steps here)
3. Core Workflow (the unique value — only input-specific content)
4. DoD Additions (input-specific deltas only — references §4/§6 for the rest)
5. Final Report Additions (skill-specific fields only — references §8)
6. Completion Checklist (ends with self-verification via `lore:doc-validator`)
7. Reference Example

A skill must contain ONLY input-specific content. If something is already a global rule (in `lore-methodology.md` or the repo's `CLAUDE.md`), reference it — don't repeat it.

**Source manifests (§0 Exhaust Every Source).** §0 (in `lore-methodology.md`) is the single canonical rule that documentation must use *every* available source. Each producer skill's §2 carries a "Sources you must read (per §0)" **source manifest** — the input-specific instantiation of that rule (Figma: comments, annotations, prototype flows/interactions, component variants, constraint-bearing variables; live-site: the observed run + trusted sources; brief: the brief + trusted sources). A new must-read source goes in §0 if it's global, or in the relevant skill's manifest if it's input-specific — never restated in both (Rule 4).

## Hook System

Hooks in `plugins/lore/hooks/hooks.json` (three PostToolUse enforcers + one Stop verifier + one SessionStart syncer):

- **`check-image-path.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): images must be in `static/img/`, markdown/MDX refs must use `/img/` (never `/static/img/`), images must never be placed in `docs/`, and `/mobile/` screenshots must be embedded with a raw `<img …/>` tag — markdown `![…](…/mobile/…)` refs are blocked because the Docusaurus build rewrites markdown-embedded images to hashed `/assets/images/` URLs, stripping the `/mobile/` path the half-width CSS keys on.
- **`check-frontmatter.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): every `docs/` markdown/MDX must have a closed YAML frontmatter block with 4 keys: `sidebar_position`, `title`, `description`, `tags` (tolerant of CRLF/BOM).
- **`check-no-tooling-refs.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): `docs/` markdown/MDX must not reference the authoring tooling — blocks `.claude/` paths, `CLAUDE.md` citations, and the `lore:` skill/subagent namespace (Rule 5 / §6). `lore:` requires a non-alphanumeric boundary so prose like "folklore:" is not a false positive.
- **`verify-docs.sh`** (Stop): BLOCKS (exit 2) on images under `docs/`, `/static/img/` refs, and markdown-embedded `/mobile/` images; WARNS about orphan images. Honors `stop_hook_active` to avoid loops.
- **`sync-lore-files.sh`** (SessionStart: startup|resume|clear|compact, non-blocking): keeps the plugin-owned `.claude/lore-methodology.md` in a consuming repo in sync with the installed plugin (an extensible `SOURCE|DEST|MODE` manifest; `owned` = silent `cmp`/`cp` overwrite + a one-line `systemMessage` notice, `notify-only` = report drift, never overwrite). Guarded: acts only in a repo whose `.claude/CLAUDE.md` imports the methodology file, so it never writes into non-Lore repos. Source path is `${CLAUDE_PLUGIN_ROOT}/templates/docs-layer/.claude/lore-methodology.md`. This is how always-on rule updates reach existing projects.

**Path scoping:** hooks resolve each file relative to the project root (`$CLAUDE_PROJECT_DIR`, else payload `cwd`) and act only on `docs/` paths. **Scope carve-out:** `.claude/`, `templates/`, and `_templates/` are skipped (intentional examples live there). JSON parsing falls back jq → python3 → sed and warns loudly if none is available rather than silently passing.

Hook paths in `hooks.json` use `${CLAUDE_PLUGIN_ROOT}`. The wizard *scripts* self-locate via `$(dirname "$0")`; the command *markdown* files must not (there `$0` is the shell) — they resolve the root via `${CLAUDE_PLUGIN_ROOT}` → glob → ask.

The hooks are covered by `tests/run-tests.sh` and CI (`.github/workflows/ci.yml`) — run `sh tests/run-tests.sh` after changing any hook or script.

## Template Layer System

Three independent, composable layers copied by `scripts/scaffold.sh`:

- **`docs-layer`** — always included: `.claude/` (CLAUDE.md — thin product layer that `@`-imports the rules; `lore-methodology.md` — plugin-owned methodology, kept in sync by the SessionStart hook; settings.json, lesson-learned.md), `docs/`, `templates/`, project `README.md`
- **`docusaurus-base`** — optional viewer **overlay**: docusaurus.config.ts, sidebars.ts, src/css/custom.css, .gitignore. The Docusaurus framework itself is fetched fresh via `create-docusaurus@latest` (always latest) by `/lore:add-docusaurus`, not bundled here.
- **`rtl-assets`** — optional: Persian font (self-hosted Vazirmatn `@font-face` with webpack-relative URLs inside `custom-rtl.css`) + right-to-left CSS (only when Docusaurus chosen AND language is RTL)

`scaffold.sh` never overwrites existing files (safe to re-run). Placeholder filling (`{{PRODUCT_NAME}}`, `{{LOCALE}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`, `{{DOC_LANGUAGE}}`) is the command's responsibility, not the script's.

**MDX caveat:** never put `{{...}}` in files under `docs/` — Docusaurus evaluates `{...}` as JavaScript and the build fails. Placeholders live only in config/template files.

## Subagent Naming

All subagent and skill references use the `lore:` namespace prefix: `lore:doc-validator`, `lore:figma-extractor`, `lore:site-explorer`, `lore:figma-to-doc`, etc.

## Versioning

Semantic versioning in `plugins/lore/.claude-plugin/plugin.json`. The release checklist for every version:

1. Bump the version in `plugins/lore/.claude-plugin/plugin.json`.
2. Bump every other hardcoded version string so they all match: the README version badge (`README.md`, the `img.shields.io/badge/version-X.Y.Z` URL) and `website/landing/src/config.ts` (`SITE.version`). The site header badges resolve from the git tag at build time, so they need no manual edit — but they only update on a redeploy that runs *after* the tag is pushed (see step 5).
3. Record the changes under a new `## X.Y.Z` section in `CHANGELOG.md`.
4. Tag the release: annotated `vX.Y.Z` (`git tag -a vX.Y.Z -m "vX.Y.Z — <summary>"`), matching the existing tag style.
5. **Publish a GitHub Release** for the tag, using that version's `CHANGELOG.md` section as the notes (`gh release create vX.Y.Z --title "Lore vX.Y.Z" --notes-file <section> --latest`). Every tag should have a corresponding published Release. The deploy workflows trigger on pushes to `main`, not on tags, so the merge-commit deploy builds the badge from the *previous* tag — re-run `deploy-landing.yml` / `deploy-docs.yml` (`workflow_dispatch`) after the tag exists, then verify the live badge.

The README is the single source of truth for consumer install/update/pin commands — don't restate them here (Rule 4).
