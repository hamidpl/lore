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
  hooks/                           # hooks.json + 14 shell scripts (output enforcement + evidence gates + methodology sync)
    ARCHITECTURE.md                # WHY each hook exists — read before changing one
  scripts/                         # scaffold.sh, detect-project.sh, figma-probe.sh, optimize-images.sh (self-locating)
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

## The Evidence Model (DoD §0.1–§0.4)

The second load-bearing principle, added in 0.7.0 after three BLOCKING rules were skipped in one real run:

> **A rule that is enforced only by prose is enforced by nothing.** The agent that skipped a step is the same agent that writes the report saying it didn't — so an obligation discharged by writing a sentence always passes.

Every §0 obligation therefore has to be **falsifiable**. The four rules that express this — **§0.1 receipts, §0.2 negative-result protocol, §0.3 no assumed inaccessibility, §0.4 run contract** — are canonical in `templates/docs-layer/.claude/lore-methodology.md`; read them there rather than here (Rule 4). That file also defines the **enforcement carve-out** that governs how much of a rule may appear elsewhere: an *operational instantiation* (columns to fill, a checklist item, a hook's error message) may live at the point of work; the rule's *wording and rationale* may not. The test is "if the canonical rule changed, would this copy become wrong?"

**Threat model — read this before hardening anything.** The adversary is a **careless collaborator, not an attacker**: a model that skips work and then writes a sentence saying it didn't. Unforgeability is explicitly **not** a property this architecture can have — every evidence artifact is a plain file under `.claude/`, and an agent with `Bash` can write one. The bar every gate is designed to is: *false evidence is not something the model produces by accident, and producing it deliberately requires an action it has no reason to take.* Any document claiming more than that is a defect — the last release shipped believing it had closed this class of bug partly because its own notes overstated the guarantee.

Two structural consequences worth preserving:

- **The evidence log is written by a hook, not the model.** `.claude/sources/.evidence-log` and `.validator-receipt` are not authored in the ordinary course of writing documentation — which is what makes "you claimed this source but never fetched it" a *deterministic* check rather than a judgement call. It is a guard against a skipped step, not a tamper-proof record (see the threat model above).
- **A zero is only a zero once the probe is proven — by a control needle, never by a flag.** The validator's own §0.2 battery leans on searching the saved payloads, and in one run *two independent mechanisms* made those searches silently return nothing: the environment's `grep` skipped `.claude/sources/raw/` because it is git-ignored, and some payloads store text in `\uXXXX` escapes where a raw UTF-8 needle cannot match. Both exit cleanly with zero hits, and no portable flag fixes both (`--no-ignore-files` is rejected by BSD grep). So the canonical rule (§0.2) prescribes a **control**: run a needle you have already proven present through the same command over the same paths, and if that also returns nothing, the probe is broken. Naming a tool or flag instead would have broken on the next machine — and note the shape of this bug, which is the general lesson: *the tool enforcing §0.2 was itself failing §0.2*. That is also why the quoted-string sweep (which issues BLOCKING verdicts from "not found") shipped **with** this rule, never before it: an always-on sweep over a broken probe is worse than no sweep, because it condemns correct documentation with confidence.
- **Never hard-code a third-party field name for an undocumented schema.** The Figma annotation bug (`notes` vs `label`) turned a schema drift into a confident `0 annotations — confirmed none`. `scripts/figma-probe.sh` selects on the *presence* of the `annotations` array and dumps whole objects; no annotation field name appears in it at all. Apply the same reflex to any new extractor.

## The Delivery Boundary (Auto-Validation Rule)

The third load-bearing principle, added in 0.9.0 after a single delivery took **seven** validation rounds and four of them found defects that had not existed the round before:

> **The loop is not the validator's. It is the fixing.** `lore:doc-validator` is read-only and changes nothing; in the incident every fix was made by the main agent, under time pressure, one at a time, sometimes while a round is still in flight — and a fix is a claim that has been through none of the checks the original went through. Three of those seven rounds were self-inflicted this way.

Since 1.0.0 the fixing has an owner of its own: **`lore:doc-reviser`**, a subagent with `Read, Edit, Grep, Glob` and nothing else, that applies the validator's `mechanical`/`content` findings as one batch at the `Targets` the report names. The design follows an Aug-2026 review of the multi-agent literature, whose load-bearing numbers are recorded in the 1.0.0 CHANGELOG entry (the working notes were local and are gone): revision by the author's own context breaks ~31% of previously-correct content per round, *narrower* one-at-a-time feedback breaks *more* (32% at one finding per round vs 19% at four), and a separate literal reviser cut that break rate by about two-thirds. So: batch the *what*, constrain the *where*, and never let the fixer fetch — the one defect it then cannot introduce is a fabricated receipt. Findings that need new evidence go back to extraction; findings that need a product decision go to the user; a reviser that rejects a fix against the evidence is a disagreement the user settles. Every `Required Action` therefore carries `Class / Targets / Evidence / Counter / Severity / Fix` (canonical in `skills/doc-reviewer/SKILL.md`), and a blocking finding with no `Evidence:` does not count.

Three structural consequences, all of them canonical in the methodology's **Auto-Validation Rule** — read them there (Rule 4):

- **A green verdict ends that delivery; a later edit is the next one.** Enforced by the digest gate above, which is what makes "unvalidated" a fact about content rather than a guess about mtime.
- **"Small" is not a safety class.** The incident's worst cascade was a spelling fix: one word, applied tree-wide, that landed inside quoted UI strings and falsified twenty-one pages while every changed line still read correctly in the diff. A hook cannot judge this — which is why the gate reports to the *user* and `remind-mass-edit.sh` only advises.
- **Two consecutive rounds of fix-introduced defects means stop, not round three.** The classification is prose (`pre-existing` / `introduced-since-last-green`, which the validator derives from the receipt's digests), so the circuit breaker is a methodology rule; the deterministic layer contributes the round count in `.validator-history` and surfaces it in the block message.

Two smaller rules from the same incident, both canonical in the methodology: **nothing under `docs/` is evidence about the product** (a normalised file of our own, cited to prove what the product does, is a §0 failure — this is how a *correct* sentence got "fixed" into a wrong one across 21 pages), and **a `[u#]` row is scoped to one run, so a standing product decision must live in the product layer and be referenced, never frozen in a census row** (`check-census.sh` blocks a `Standing:` row that references nothing).

## Rule 4: Single Place of Truth (BLOCKING)

Every fact exists in exactly one canonical location; everywhere else references it. This is the most important authoring constraint:

| Fact category | Canonical location |
|---------------|--------------------|
| Methodology: General Rules + DoD §0/§2/§4–§8 | `templates/docs-layer/.claude/lore-methodology.md` (plugin-owned; synced into each repo) |
| Product-layer DoD: trusted sources §1, user roles §3 | Consuming repo's `.claude/CLAUDE.md` |
| Input-specific workflow | The relevant skill (`skills/{name}/SKILL.md`) |
| Lessons learned | Consuming repo's `.claude/lesson-learned.md` |
| Document structure template — including the edge-case coverage taxonomy and the `States to Design` table + its three status values | `templates/docs-layer/templates/product-document-template.md` |
| Skill structure template | `templates/skill-template.md` |
| Hook rationale: why each hook exists, the incident behind it, the change that would undo it | `plugins/lore/hooks/ARCHITECTURE.md` (`CLAUDE.md` carries the index only) |

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

**The edge-case taxonomy is one list, and the skills only reference it.** Both producer skills walk it per scenario; `figma-to-doc` used to carry its own four-item copy ("empty, error, loading, permission-denied") and the canonical taxonomy had no `loading` category at all — a silent divergence nothing could catch. A test now asserts that no skill re-lists the taxonomy inline and that every category a skill names exists in the template.

Its output is deliberately **two things for two readers**: an Extension or a `[NEEDS DESIGN]`/`[CLARIFICATION NEEDED]` marker at the step it belongs to, *and* a row in the template's `## States to Design` table — the flat list a designer reads without re-reading every scenario. The table's three status values (`specified — needs design` / `unspecified — needs decision + design` / `designed`) separate a design task from a product decision, which one marker could not. The table is also **exempt from the ~5-question cap** in `brief-to-doc`: asking costs the user's attention, listing costs nothing. And the template states explicitly that *naming a required state is not inventing behavior* — without that, the no-invention rule reads as forbidding the table and the model leaves it empty.

**Source manifests (§0 Exhaust Every Source).** §0 (in `lore-methodology.md`) is the single canonical rule that documentation must use *every* available source. Each producer skill's §2 carries a "Sources you must read (per §0)" **source manifest** — the input-specific instantiation of that rule (Figma: comments, annotations, prototype flows/interactions, component variants, constraint-bearing variables; live-site: the observed run + trusted sources; brief: the brief + trusted sources). A new must-read source goes in §0 if it's global, or in the relevant skill's manifest if it's input-specific — never restated in both (Rule 4).

## Hook System

**The rationale for every hook lives in [`plugins/lore/hooks/ARCHITECTURE.md`](plugins/lore/hooks/ARCHITECTURE.md) — read it before changing, adding, or removing one.** What each hook exists to stop, the incident that produced it, and the plausible-looking change that would quietly undo it are all there and nowhere else. Several guards look redundant precisely because what they catch has been caught once already; the file is what stops a second time. This section is only the index.

Hooks in `plugins/lore/hooks/hooks.json` split into two families: **output enforcers** (is the markdown shaped right?) and **evidence enforcers** (did the work actually happen?).

| Hook | Event (blocking?) | Enforces |
|------|-------------------|----------|
| `check-image-path.sh` | PostToolUse Write\|Edit — ⛔ | images live in `static/img/`, refs use `/img/`, none under `docs/`, `/mobile/` embedded as raw `<img>` |
| `check-frontmatter.sh` | PostToolUse Write\|Edit — ⛔ | every `docs/` page has the 4 frontmatter keys |
| `check-no-tooling-refs.sh` | PostToolUse Write\|Edit — ⛔ | `docs/` never references the authoring tooling (Rule 5 / §6) |
| `verify-docs.sh` | Stop — ⛔ | output checks **plus** the four process gates: a census exists, each is complete, `[u#]` rows are resolved, and the last validator verdict is green over the *current content* |
| `sync-lore-files.sh` | SessionStart — advisory | keeps a repo's `.claude/lore-methodology.md` in sync with the installed plugin |
| `record-evidence.sh` | PostToolUse (fetch-ish tools) — never blocks | writes `.claude/sources/.evidence-log`; the `verified`/`mentioned` tier split is the load-bearing part |
| `check-citation-loss.sh` | PreToolUse Edit\|Write — ⛔ | an edit may not drop a URL whose host has a `verified` fetch |
| `check-census.sh` | PostToolUse Write\|Edit — ⛔ / `--complete` at Stop | census **shape** at write time, **completeness** at Stop — the split is deliberate |
| `record-validator-run.sh` | SubagentStop `lore:doc-validator` — never blocks | writes `.validator-receipt` (verdict + per-file digest + coverage) and appends `.validator-history` |
| `guard-reviser-edit.sh` | PreToolUse Edit\|Write — ⛔ | confines `lore:doc-reviser` to targeted edits under `docs/` |
| `guard-under-review.sh` | PreToolUse Edit\|Write\|Task — ⛔ | while the verdict is BLOCKED, only a reviser run may edit `docs/` |
| `require-worker-evidence.sh` | SubagentStop `lore:figma-extractor` — ⛔ | a worker may not finish without a receipt that exists on disk |
| `remind-census.sh` | PreToolUse Write — advisory | restates §0 when a new `docs/` page appears with no census |
| `remind-mass-edit.sh` | PreToolUse Edit\|Bash — advisory | the tree-wide-edit checklist; advisory because the judgement is exactly what went wrong |

Four invariants that constrain *any* hook change, and whose reasoning is in the architecture file:

- **Every hook guards on the Lore marker** (`.claude/CLAUDE.md` containing `@lore-methodology.md`) and exits 0 otherwise. Not an optimisation — without it, installing Lore imposes its DoD on unrelated repos.
- **Path scoping** is relative to the project root, `docs/`-only, with `.claude/`, `templates/` and `_templates/` carved out — `check-census.sh` is the single deliberate exception.
- **`lib/common.sh` is sourced as `. "$(dirname "$0")/lib/common.sh"`, never via `${CLAUDE_PLUGIN_ROOT}`**, and must not carry the exec bit. Both are asserted by tests.
- **CI derives its hook lists from `hooks.json`; never hardcode them.**

Hook paths in `hooks.json` use `${CLAUDE_PLUGIN_ROOT}`. The wizard *scripts* self-locate via `$(dirname "$0")`; the command *markdown* files must not (there `$0` is the shell) — they resolve the root via `${CLAUDE_PLUGIN_ROOT}` → glob → ask.

Run `sh tests/run-tests.sh` after changing any hook or script.

## Image Weight (`scripts/optimize-images.sh`)

Both image sources are heavy by default — Figma exports at `scale=2` (a 1440px frame lands as 2880px) and Playwright screenshots are raw PNG — and both are **committed to the consuming repo and served by the site**, so nothing reclaims that weight later. Measured on real UI captures: **72% saved, dimensions unchanged, no visible difference.**

Three design points worth keeping:

- **One batch, after all captures — and the reason is not process cost.** Spawning a compressor per image costs ~10ms; what it actually costs is *one agent tool round-trip per image*, so forty images means forty round-trips instead of one call. The skills therefore run it once, after every capture has landed (figma-to-doc Phase 2 step 8; site-to-doc after the explorer subagent and any responsive pass) — never inside `lore:site-explorer`, which runs once per pass.
- **The quality floor is the safety property, not a setting.** `pngquant --quality=65-90` exits 99 and leaves the file **untouched** when it cannot hold the floor, so "don't damage quality" is enforced by the tool rather than by anyone's judgement. A lossless pass follows on the result. PNG stays PNG: WebP would save more but changes every extension, doc reference and census row — deliberately deferred.
- **Idempotence is correctness, not speed.** A second lossy pass over the same file degrades it again, so `.claude/sources/.image-optim` records the fingerprint of each *optimized* result and those files are skipped. A re-captured screenshot has a new fingerprint and is optimized afresh — which is right, since it is a new original.

With no optimizer installed the script reports `tool=none`, changes nothing, and exits 0 — it never claims a saving it did not make, and never fails a run over a missing optional binary. `verify-docs.sh` warns (never blocks) about large PNGs absent from the manifest, for the same reason.

## Template Layer System

Three independent, composable layers copied by `scripts/scaffold.sh`:

- **`docs-layer`** — always included: `.claude/` (CLAUDE.md — thin product layer that `@`-imports the rules; `lore-methodology.md` — plugin-owned methodology, kept in sync by the SessionStart hook; settings.json, lesson-learned.md), `docs/`, `templates/`, project `README.md`, and `.gitignore`. The `.gitignore` is **not optional safety**: it is the only thing keeping an exported browser session (`.claude/.auth/`) out of git in a docs-only project, and a committed session token is irreversible.
- **`docusaurus-base`** — optional viewer **overlay**: docusaurus.config.ts, sidebars.ts, src/css/custom.css, .gitignore. The Docusaurus framework itself is fetched fresh via `create-docusaurus@latest` (always latest) by `/lore:add-docusaurus`, not bundled here.
- **`rtl-assets`** — optional: Persian font (self-hosted Vazirmatn `@font-face` with webpack-relative URLs inside `custom-rtl.css`) + right-to-left CSS (only when Docusaurus chosen AND language is RTL)

`scaffold.sh` never overwrites existing files (safe to re-run). **The one exception is `.gitignore`, which is merged, not skipped** — every layer contributes entries, so a docs-only project that later gains Docusaurus must end up with both sets. Skipping it would silently drop a whole layer's ignores. The merge only appends lines that are not already present, so re-running stays idempotent and a user's own entries are never touched. Placeholder filling (`{{PRODUCT_NAME}}`, `{{LOCALE}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`, `{{DOC_LANGUAGE}}`) is the command's responsibility, not the script's.

**MDX caveat:** never put `{{...}}` in files under `docs/` — Docusaurus evaluates `{...}` as JavaScript and the build fails. Placeholders live only in config/template files.

## Subagent Naming

All subagent and skill references use the `lore:` namespace prefix: `lore:doc-validator`, `lore:doc-reviser`, `lore:figma-extractor`, `lore:site-explorer`, `lore:figma-to-doc`, etc.

## Versioning

Semantic versioning in `plugins/lore/.claude-plugin/plugin.json`. The release checklist for every version:

1. Bump the version in `plugins/lore/.claude-plugin/plugin.json`.
2. Bump the one other hardcoded version string so they match: the README version badge (`README.md`, the `img.shields.io/badge/version-X.Y.Z` URL). **CI asserts these two agree**, so a half-bumped release fails the PR rather than shipping. The site header badges resolve from the git tag at build time and need no manual edit — but they only update on a redeploy that runs *after* the tag is pushed (see step 5).

   *There is no third string.* `website/landing/src/config.ts` used to carry `SITE.version`; it had zero consumers, so bumping it was pure ceremony and its stale fallback could ship a wrong badge. It was deleted in 0.7.0 — do not reintroduce it.
3. Record the changes under a new `## X.Y.Z` section in `CHANGELOG.md`.
4. Tag the release: annotated `vX.Y.Z` (`git tag -a vX.Y.Z -m "vX.Y.Z — <summary>"`), matching the existing tag style.
5. **Publish a GitHub Release** for the tag, using that version's `CHANGELOG.md` section as the notes (`gh release create vX.Y.Z --title "Lore vX.Y.Z" --notes-file <section> --latest`). Every tag should have a corresponding published Release. The deploy workflows trigger on pushes to `main`, not on tags, so the merge-commit deploy builds the badge from the *previous* tag — re-run `deploy-landing.yml` / `deploy-docs.yml` (`workflow_dispatch`) after the tag exists, then verify the live badge.

The README is the single source of truth for consumer install/update/pin commands — don't restate them here (Rule 4).
