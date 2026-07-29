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
  hooks/                           # hooks.json + 9 shell scripts (output enforcement + evidence gates + methodology sync)
  scripts/                         # scaffold.sh, detect-project.sh, figma-probe.sh (self-locating)
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
- **Never hard-code a third-party field name for an undocumented schema.** The Figma annotation bug (`notes` vs `label`) turned a schema drift into a confident `0 annotations — confirmed none`. `scripts/figma-probe.sh` selects on the *presence* of the `annotations` array and dumps whole objects; no annotation field name appears in it at all. Apply the same reflex to any new extractor.

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

Hooks in `plugins/lore/hooks/hooks.json` split into two families: **output enforcers** (is the markdown shaped right?) and **evidence enforcers** (did the work actually happen?).

### Output enforcers

- **`check-image-path.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): images must be in `static/img/`, markdown/MDX refs must use `/img/` (never `/static/img/`), images must never be placed in `docs/`, and `/mobile/` screenshots must be embedded with a raw `<img …/>` tag — markdown `![…](…/mobile/…)` refs are blocked because the Docusaurus build rewrites markdown-embedded images to hashed `/assets/images/` URLs, stripping the `/mobile/` path the half-width CSS keys on.
- **`check-frontmatter.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): every `docs/` markdown/MDX must have a closed YAML frontmatter block with 4 keys: `sidebar_position`, `title`, `description`, `tags` (tolerant of CRLF/BOM).
- **`check-no-tooling-refs.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): `docs/` markdown/MDX must not reference the authoring tooling — blocks `.claude/` paths, `CLAUDE.md` citations, and the `lore:` skill/subagent namespace (Rule 5 / §6). `lore:` requires a non-alphanumeric boundary so prose like "folklore:" is not a false positive.
- **`verify-docs.sh`** (Stop): BLOCKS (exit 2) on images under `docs/`, `/static/img/` refs, and markdown-embedded `/mobile/` images; WARNS about orphan images. Honors `stop_hook_active` to avoid loops. Also carries the two **process gates** below.
- **`sync-lore-files.sh`** (SessionStart: startup|resume|clear|compact, non-blocking): keeps the plugin-owned `.claude/lore-methodology.md` in a consuming repo in sync with the installed plugin (an extensible `SOURCE|DEST|MODE` manifest; `owned` = silent `cmp`/`cp` overwrite + a one-line `systemMessage` notice, `notify-only` = report drift, never overwrite). Guarded: acts only in a repo whose `.claude/CLAUDE.md` imports the methodology file, so it never writes into non-Lore repos. Source path is `${CLAUDE_PLUGIN_ROOT}/templates/docs-layer/.claude/lore-methodology.md`. This is how always-on rule updates reach existing projects.

### Evidence enforcers (DoD §0.1–§0.4)

These exist because a §0 obligation used to be discharged by *writing a sentence*: `nothing relevant — confirmed searched` is byte-identical whether the source was read or never touched, and the agent that skipped the work authors the sentence. The fix is to make claims **falsifiable against artifacts a hook wrote**.

- **`record-evidence.sh`** (PostToolUse: `WebFetch|Task|Bash|Write|Edit|mcp__.*(playwright|browser|chrome|puppeteer|fetch).*`, never blocks): appends one TAB-separated line per fetch / subagent run to `.claude/sources/.evidence-log` — `iso8601, tool, detail, tier`.

  **Tiers are the load-bearing part.** `verified` means a fetching tool actually ran (WebFetch, browser navigation, a subagent, and `figma-probe.sh` appending its own entry once it has an HTTP status). `mentioned` means a URL merely appeared inside a Bash command — `grep -rn "https://x" ./notes` contacted nothing, and a failed `curl` contacted nothing either. `check-census.sh` accepts only `verified` as proof a source was read. Without the split, ordinary work manufactured receipts. Lines with no 4th field predate tiering and are read as `verified`.

  Values come from tool input, so they are sanitised before writing: for every tool but Bash only the first line is kept (an embedded newline used to append a second, forged entry), and all control characters are stripped per line (an embedded tab forged the tier column).

- **`check-census.sh`** — the single place every census rule lives, in **two modes**:
  - *(default)* PostToolUse Write|Edit, BLOCKING exit 2 — validates **shape**: the `## Run contract` block exists (§0.4); every `[t#]` trusted-source row carries an HTTP status **and** a `.claude/sources/raw/` path, whether it found something or nothing (§0.1 — receipts used to be checked only on zero-case rows, so the majority of rows went unexamined); every zero-case line carries the same receipt; `corroboration=RAW-HAS-…` anywhere is a blocking parser failure (§0.2); every cited raw payload exists and is non-empty; every claimed URL's host appears in `.evidence-log` as a **verified** fetch; cited screenshots exist. Fenced blocks are skipped — a quoted format example is not a claim.
  - `--complete <file>`, invoked by `verify-docs.sh` at Stop, BLOCKING exit 2 — validates **completeness**: a `site-*` census has `## Observation coverage` with at least one `[o#]` row; a `figma-*` census has a `## Counts` row carrying a **number** for each manifest source type.

  **Why the split.** Completeness used to be enforced at write time, which blocked the exact pre-flight census the skills prescribe (`site-to-doc:30`, `figma-to-doc:140`). The cheapest way out of that block was a placeholder — an empty `## Observation coverage` heading, or one prose line naming the six Figma source types — and the placeholder then satisfied the check **for the rest of the run**, because nothing re-examined it. The gate taught the model to disarm the gate. Shape at write, completeness at Stop.
- **`record-validator-run.sh`** (SubagentStop: `lore:doc-validator`, never blocks): writes `.claude/sources/.validator-receipt` with the timestamp and the verdict parsed from the subagent's own final message (`APPROVED` / `APPROVED WITH WARNINGS` / `BLOCKED` / `UNKNOWN`).
- **`remind-census.sh`** (PreToolUse: Write, never blocks): when a *new* `docs/` page is created and no census exists, injects `additionalContext` restating the §0 obligations at the moment of the action. Deliberately advisory — denying would false-block `/lore:init` (which scaffolds `docs/intro.md`) and hand edits.
- **`verify-docs.sh` process gates** (Stop, BLOCKING): (a) **the session produced no census at all** — every §0 rule is checked against that file and `check-census.sh` only fires when one is written, so a run that never writes one skips all of them at once; requiring the artifact is what makes the rest of the evidence layer reachable (this is the gap that made 0.7.0's headline guarantee untrue); (b) each census fails `check-census.sh --complete`; (c) any `[u#]` run-contract row whose status field is not exactly `satisfied` (with a non-empty evidence cell) or `waived` (§0.4); (d) documentation newer than the validator receipt, no receipt at all, or a non-green verdict. Both fire **only when `.claude/sources/` exists AND this session produced documentation** — the session id must appear in `.claude/sources/.docs-touched`. That marker is git-ignored, so **its absence means "no session here has produced docs", never "unknown, therefore block"**: reading it the other way blocked every session in every clone of a Lore repo. Hand-maintained docs trees are never gated.

  Status matching is **whole-field, not substring**. `grep -v satisfied` filtered out `not satisfied` and `unsatisfied` — the exact phrasing §0.4's own wording primes the model to write — so the gate passed the failure it was built to catch. The same defect existed in `record-validator-run.sh`'s verdict parsing (a report saying "nothing was BLOCKED" became a BLOCKED verdict); both now require the token to open a line.

**Known limits** (state these when they come up): a source fetched before this shipped is not in the log, so the first post-upgrade run re-fetches; URL matching is by host, which is deliberately permissive to keep false blocks near zero.

**Project scoping (every hook, no exceptions).** A plugin is installed per *user*, so every hook runs in whatever repo the session happens to be in. **All nine hooks therefore guard on the Lore marker** — a `.claude/CLAUDE.md` containing `@lore-methodology.md` — and exit 0 immediately otherwise. This is not an optimisation. Without it, installing Lore imposed its Definition of Done on unrelated projects: any repo keeping plain markdown or an image under `docs/` had those writes blocked, and `verify-docs.sh` blocked **every turn** there. The rules in this plugin are Lore's DoD, not universal truth, and a repo that never opted in must be untouched.

**Path scoping:** hooks resolve each file relative to the project root (`$CLAUDE_PROJECT_DIR`, else payload `cwd`) and act only on `docs/` paths. **Scope carve-out:** `.claude/`, `templates/`, and `_templates/` are skipped (intentional examples live there) — **except `check-census.sh`**, whose entire job is the evidence artifact under `.claude/sources/`; it is the single deliberate exception. Hooks on high-frequency matchers (`Write|Edit`, `Bash`) additionally bail on a cheap substring test *before* starting a JSON parser, so an unrelated repo pays almost nothing. JSON parsing falls back jq → python3 → text scan and warns loudly if none is available rather than silently passing.

### `hooks/lib/common.sh` — the shared prologue

All of the above — the parser ladder, root resolution, the Lore-marker guard, the carve-out — lives in **one sourced library**, not in each hook. It used to be copy-pasted into seven of the nine, about a third of the hook layer, which is how a single greedy-`sed` defect came to exist in seven places at once.

Two invariants:

- **Source it as `. "$(dirname "$0")/lib/common.sh"`, never via `${CLAUDE_PLUGIN_ROOT}`.** `hooks.json` interpolates that variable into the *command string*; nothing guarantees it is also exported into the hook's environment, so a hook resolving its own library through it would fail to find it. `$0` is always the real path. A test asserts no hook does this.
- **It is sourced, never executed** — so it sits outside the `hooks/*.sh` glob and must *not* carry the exec bit. CI and `run-tests.sh` both assert that, in the opposite direction from every other script.

`json_field` takes **one** argument: a space-separated key path (`json_field 'tool_input file_path'`). Each backend derives its own form from it. It used to take three — a jq filter, a python path and a bare `sed` key — which meant every call site restated the same path in three dialects and could get them out of step. The text fallback (used only when neither jq nor python3 exists) honours the **path** and takes the **first** match: `s/.*"file_path".../` is greedy, so it returned the *last* occurrence in the payload — the `tool_response` echo rather than `tool_input` — on every `Write`. It also reads unquoted scalars, because `stop_hook_active` is a boolean and a string-only scan silently disabled the Stop hook's loop guard.

Hook paths in `hooks.json` use `${CLAUDE_PLUGIN_ROOT}`. The wizard *scripts* self-locate via `$(dirname "$0")`; the command *markdown* files must not (there `$0` is the shell) — they resolve the root via `${CLAUDE_PLUGIN_ROOT}` → glob → ask.

The hooks are covered by `tests/run-tests.sh` and CI (`.github/workflows/ci.yml`) — run `sh tests/run-tests.sh` after changing any hook or script.

**CI derives its lists from `hooks.json`; never hardcode them.** The exec-bit and wiring checks used to name four hooks by hand, so five shipped uncovered — and because git tracks the exec bit while the suite invokes hooks as `sh <file>` (which does not need it), one `chmod`-less commit could ship a dead hook with everything green. CI now walks every command in `hooks.json` plus every `.sh` under `hooks/` and `scripts/`, and `run-tests.sh` mirrors the same check so it fails locally first. The old `claude plugin validate` step sat behind `if command -v claude` and never ran on a runner — dead coverage that read as coverage; it is replaced by manifest/layout assertions that do run, plus a check that the README version badge matches `plugin.json`.

## Template Layer System

Three independent, composable layers copied by `scripts/scaffold.sh`:

- **`docs-layer`** — always included: `.claude/` (CLAUDE.md — thin product layer that `@`-imports the rules; `lore-methodology.md` — plugin-owned methodology, kept in sync by the SessionStart hook; settings.json, lesson-learned.md), `docs/`, `templates/`, project `README.md`, and `.gitignore`. The `.gitignore` is **not optional safety**: it is the only thing keeping an exported browser session (`.claude/.auth/`) out of git in a docs-only project, and a committed session token is irreversible.
- **`docusaurus-base`** — optional viewer **overlay**: docusaurus.config.ts, sidebars.ts, src/css/custom.css, .gitignore. The Docusaurus framework itself is fetched fresh via `create-docusaurus@latest` (always latest) by `/lore:add-docusaurus`, not bundled here.
- **`rtl-assets`** — optional: Persian font (self-hosted Vazirmatn `@font-face` with webpack-relative URLs inside `custom-rtl.css`) + right-to-left CSS (only when Docusaurus chosen AND language is RTL)

`scaffold.sh` never overwrites existing files (safe to re-run). **The one exception is `.gitignore`, which is merged, not skipped** — every layer contributes entries, so a docs-only project that later gains Docusaurus must end up with both sets. Skipping it would silently drop a whole layer's ignores. The merge only appends lines that are not already present, so re-running stays idempotent and a user's own entries are never touched. Placeholder filling (`{{PRODUCT_NAME}}`, `{{LOCALE}}`, `{{DIRECTION}}`, `{{HTML_LANG}}`, `{{DOC_LANGUAGE}}`) is the command's responsibility, not the script's.

**MDX caveat:** never put `{{...}}` in files under `docs/` — Docusaurus evaluates `{...}` as JavaScript and the build fails. Placeholders live only in config/template files.

## Subagent Naming

All subagent and skill references use the `lore:` namespace prefix: `lore:doc-validator`, `lore:figma-extractor`, `lore:site-explorer`, `lore:figma-to-doc`, etc.

## Versioning

Semantic versioning in `plugins/lore/.claude-plugin/plugin.json`. The release checklist for every version:

1. Bump the version in `plugins/lore/.claude-plugin/plugin.json`.
2. Bump the one other hardcoded version string so they match: the README version badge (`README.md`, the `img.shields.io/badge/version-X.Y.Z` URL). **CI asserts these two agree**, so a half-bumped release fails the PR rather than shipping. The site header badges resolve from the git tag at build time and need no manual edit — but they only update on a redeploy that runs *after* the tag is pushed (see step 5).

   *There is no third string.* `website/landing/src/config.ts` used to carry `SITE.version`; it had zero consumers, so bumping it was pure ceremony and its stale fallback could ship a wrong badge. It was deleted in 0.7.0 — do not reintroduce it.
3. Record the changes under a new `## X.Y.Z` section in `CHANGELOG.md`.
4. Tag the release: annotated `vX.Y.Z` (`git tag -a vX.Y.Z -m "vX.Y.Z — <summary>"`), matching the existing tag style.
5. **Publish a GitHub Release** for the tag, using that version's `CHANGELOG.md` section as the notes (`gh release create vX.Y.Z --title "Lore vX.Y.Z" --notes-file <section> --latest`). Every tag should have a corresponding published Release. The deploy workflows trigger on pushes to `main`, not on tags, so the merge-commit deploy builds the badge from the *previous* tag — re-run `deploy-landing.yml` / `deploy-docs.yml` (`workflow_dispatch`) after the tag exists, then verify the live badge.

The README is the single source of truth for consumer install/update/pin commands — don't restate them here (Rule 4).
