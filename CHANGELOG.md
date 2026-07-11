# Changelog

All notable changes to the Lore plugin are documented here. Versioning is
[semantic](https://semver.org); the source of truth for the current version is
`plugins/lore/.claude-plugin/plugin.json`. Consumers update with
`/plugin marketplace update lore-marketplace` then `/plugin update lore@lore-marketplace`.

Lore is **pre-1.0**: minor releases may include breaking changes until `1.0.0`,
which is reserved for the first mature, general-use release.

## 0.6.0

Two architecture changes. The always-on methodology rules now live in a
plugin-owned file that auto-syncs on `/plugin update`, so rule improvements
finally reach existing projects — not just new ones. And source-gathering is
unified under one general rule, "Exhaust Every Source", with a richer Figma
source manifest.

### Methodology rules now propagate via a synced file

- **What changed.** The Definition of Done and General Rules (Rule 1–5, DoD
  §0/§2/§4–§8) moved out of each consumer repo's `.claude/CLAUDE.md` into a new
  **plugin-owned** `.claude/lore-methodology.md`. The consumer `CLAUDE.md` is now
  thin — product layer (§1 Trusted Sources, §3 User Roles, product overview,
  structure) plus your own custom rules — and `@`-imports the methodology file.
  A new `SessionStart` hook (`sync-lore-files.sh`, matchers
  `startup|resume|clear|compact`) copies the latest methodology file into the
  repo whenever it differs (silent overwrite + a one-line notice), guarded to act
  only in a repo whose `CLAUDE.md` imports it. It carries an extensible
  `SOURCE|DEST|MODE` manifest (`owned` = auto-overwrite; `notify-only` = report
  drift, never touch user-edited files).
- **Why.** `CLAUDE.md` is copied once at `/lore:init` and never updated by
  `/plugin update`, so every past rule improvement was stranded in new projects
  only. Plugins can't inject always-on context directly, but a `SessionStart`
  hook can keep an imported file current — closing the gap. Split boundary maps
  onto the existing `— PRODUCT LAYER` tags; §1/§3 stay in `CLAUDE.md` with stub
  pointers in the methodology file so §-numbering reads continuously and the
  ~115 `§N` references in skills keep resolving.
- **How verified.** Prototype validated with real `claude -p` sessions
  (`@import` loads like CLAUDE.md; subagents see the imported rules; auto-sync
  after a version bump; no approval dialog for project-local imports). Hook suite
  green (60 assertions, incl. 10 new sync-hook + scaffold cases: missing→create,
  in-sync→silent, stale→overwrite, no-import/non-Lore repo→untouched, valid
  JSON notice); `shellcheck` clean; `claude plugin validate` passes.

### One general rule: Exhaust Every Source

- **What changed.** DoD §0 is now **"Exhaust Every Source"** — a single blocking
  rule that documentation must read *every* available source for a page and
  extract everything relevant, stating any zero-case explicitly. Each producer
  skill's Pre-Flight carries a "Sources you must read (per §0)" **source
  manifest** (the input-specific instantiation). The Figma manifest is expanded
  to a maximal read: beyond comments, Dev-Mode annotations, and prototype
  flows/interactions, it now also requires **component variants/properties**
  (role/state differences) and **constraint-bearing variables** (limits, named
  states) — recorded in the source census and mirrored in `lore:figma-extractor`.
  The trusted-sources read obligation is now applied uniformly across
  figma/brief/site skills (previously uneven). `skill-template.md` gained the
  manifest slot so every future skill carries it.
- **Why.** These must-read requirements had accreted as separate blocking rules
  scattered across skills; sources (Figma annotations, trusted sources) were
  sometimes silently skipped. One general rule + per-skill manifests gives a
  single home for the principle and one obvious place to add future must-reads.
- **How verified.** `lore:doc-reviewer` / `lore:doc-validator` updated to check
  the full manifest coverage in the census; hook/validate suite green.

## 0.5.2

A rendering fix for mobile-view screenshots: they now keep their half-width
display after a Docusaurus production build, not just in dev.

### Mobile screenshots stay half-width after build

- **What changed.** Mobile-view screenshots must now be embedded with a raw
  `<img src="/img/{section}/mobile/…" alt="…" />` tag instead of markdown
  `![…](…)` syntax. The half-width rule (`.markdown img[src*="/mobile/"]`) is
  unchanged; only the embed form is. Desktop and tablet images keep markdown
  syntax. The convention is enforced at write time (`check-image-path.sh`
  Rule C, BLOCKING) and on Stop (`verify-docs.sh` check 2b), and checked by
  `lore:doc-reviewer` / `lore:doc-validator`.
- **Why.** Docusaurus rewrites markdown-embedded images to hashed
  `/assets/images/…` URLs at build time, stripping the `/mobile/` path segment
  the stylesheet keys on — so the 50% rule silently stopped applying in the
  built site (it still worked in dev). A raw `<img>` tag keeps its `src`
  verbatim through the build. Device classification is unchanged: mobile frames
  are still detected by frame **width** (≲480px), not by the word "mobile" in a
  layer/section name.
- **How verified.** Hook suite green (50 assertions, incl. new markdown-`/mobile/`
  block, raw-`<img>` pass, and alt-text-only non-false-positive cases);
  `shellcheck -S warning` clean; `claude plugin validate` passes.

## 0.5.1

A small batch of authoring-quality improvements: the generated home page is no
longer a dead stub, generated sites carry a Lore attribution, and the document
template is renamed to match Lore's own file-naming convention.

### Home page written from the product description

- **What changed.** `/lore:config` now turns the **product description** into
  real output. The description is stored once in a new **Product Overview —
  PRODUCT LAYER** block in the project's `.claude/CLAUDE.md` (its canonical home,
  Rule 4), and from it the command rewrites `docs/intro.md` into an actual
  product introduction and refreshes the Docusaurus `tagline`.
- **Why.** The scaffolded `docs/intro.md` shipped as a generic "replace me"
  sample, and the description question existed but was never written anywhere.
- **How verified.** Hook/scaffold suite green; the reworded intro starter stays
  free of tooling references (Rule 5) and of `{{...}}` (MDX-safe under `docs/`).

### "Built with Lore" footer attribution

- **What changed.** Docusaurus-generated sites now show a localized
  **"ساخته شده با Lore" / "Built with Lore"** link to
  [lorekit.net](https://lorekit.net) in the footer copyright line. It lives in
  the site chrome only — never inside `docs/` content — filled per the
  documentation language ("Lore" stays Latin).
- **How verified.** `scaffold + docusaurus build` CI green; the filled copyright
  renders as a single well-formed anchor in both RTL and LTR.

### Document template renamed

- **What changed.** The canonical document template is renamed
  `Product Document Template.md` → `product-document-template.md`, and the folder
  it lands in inside a project is renamed `docs-template/` → `templates/`. All
  path references were updated across the plugin.
- **Why.** Aligns the template's own file/folder naming with the lowercase,
  hyphenated convention Lore enforces everywhere else.

## 0.5.0

Adds a shared **edge-case coverage taxonomy** plus methodology upgrades across
all four skills — making scenario coverage systematic instead of ad-hoc, while
keeping the no-invention principle supreme.

### Edge-case coverage taxonomy (single source of truth)

- **What changed.** The Product Document Template gains a compact **edge-case
  coverage taxonomy** in the `Scenarios` section — nine categories (empty/null,
  boundaries, errors, concurrency, state transitions, permissions, invalid
  input, internationalization, bulk operations), roughly ordered by
  production-defect frequency. It is guidance inside the Scenarios explanation,
  not a new output section.
- Defined once in the template (Rule 4); the global §4 rule, all three producer
  skills, `lore:doc-reviewer`, and `lore:doc-validator` **reference** it and add
  only their input-specific application — no skill re-lists the categories.

### Per-skill upgrades

- **`lore:brief-to-doc`.** A **brief-readiness gate** (warns and asks before
  generating from a brief missing acceptance criteria / personas / out-of-scope);
  a **clarification-question cap** (~5, impact-ordered; the rest become
  placeholders); **Gherkin acceptance-criteria mapping** (Given → Preconditions,
  When/Then → a Main Flow step, failures → Extensions); the taxonomy used as a
  **question engine** (a silent-but-applicable category becomes a
  category-attributed question or placeholder, never a fabricated Extension); and
  an **AC testability rule** (subjective criteria are flagged, not accepted).
- **`lore:site-to-doc`.** Edge-case coverage delegates to the taxonomy; limits
  get a **three-value boundary probe** (below/at/above — e.g. 99/100/101),
  **state transitions** are exercised (Back mid-flow, direct mid-state URL), and
  a tight budget is triaged by the taxonomy's frequency order.
- **`lore:figma-to-doc`.** A taxonomy-driven **missing-states check**: each
  feature's design is checked for empty / error / loading / permission-denied
  frames; an absent state becomes a clarification question, never an invented
  screen.
- **`lore:doc-reviewer` / `lore:doc-validator`.** A scenario with a missing or
  empty **Extensions** block is flagged as a **warning** (non-blocking), and
  Extensions coverage is judged against the taxonomy — scoped to projects whose
  template defines one, so existing repos see no false warnings.

### Migration

- `scaffold.sh` never overwrites, so **existing** projects get the updated skills
  via `/plugin update` but keep their old template. To gain the full benefit,
  copy the **Edge-case coverage taxonomy** block from the plugin's
  `templates/docs-layer/docs-template/Product Document Template.md` into your
  project's `docs-template/` copy.

### Verified

- `sh tests/run-tests.sh` (44 passed), `claude plugin validate ./plugins/lore`,
  and `npm run build` for the docs site (EN + FA) all pass; Rule 4 greps confirm
  the taxonomy text lives only in the template.

## 0.4.1

Adds **mobile/tablet view documentation**, **numbered scenarios**, and
**half-width mobile screenshots** to the documentation output.

### Mobile & Tablet View

- **What changed.** The Product Document Template gains an optional
  **Mobile & Tablet View** section (after `Scenarios`) that captures *only the
  differences* from desktop — layout reflow, hidden/moved elements, the mobile
  navigation pattern — never a re-told flow.
- **`lore:figma-to-doc`.** Frames are classified by device (from their
  `absoluteBoundingBox` width + name); when the design has mobile/tablet frames,
  documenting them is **mandatory** (the frames are already fetched, so no user
  prompt) and they export to `mobile/`/`tablet/` sub-paths. `lore:figma-extractor`
  returns the device class per frame.
- **`lore:site-to-doc`.** Because each viewport is a separate, costly browser
  pass, the responsive view is **opt-in**: a new Pre-Flight step asks once
  (none / mobile `390×844` / tablet `768×1024` / both). A responsive pass re-runs
  only the key steps through `lore:site-explorer` and counts against the page
  budget.

### Numbered scenarios

- Scenario headings are now numbered — `Scenario 1: [goal]` (localized, e.g.
  `سناریو ۱: …`). The format is defined once in the template (Rule 4); the
  global rules, all three producer skills, `lore:doc-reviewer`, and
  `lore:doc-validator` reference it. Reference examples updated.

### Half-width mobile screenshots

- **Path convention.** Mobile screenshots live under
  `static/img/{section}/mobile/`, tablet under `/tablet/`. The Docusaurus
  stylesheet renders any doc-body image whose `src` contains `/mobile/` at
  **50% width on desktop and 100% below 996px**, so tall portrait phone shots
  don't dominate the page. Width-only + `margin:auto` is direction-neutral, so
  RTL styling needs no change; Markdown stays plain, so the enforcement hooks
  are unaffected.
- **Verified.** 44/44 hook tests pass, the manifest validates, and a real
  `create-docusaurus` RTL smoke build is green with the rule compiled into the
  bundle (`.markdown img[src*="/mobile/"]` → 50% desktop / 100% <996px, scope
  intact).
- Docs synced (EN + FA `from-figma`, `from-a-live-site`, `review-and-validate`
  guides).

**Upgrade note.** Skills/agents propagate via `/plugin update`, but
`src/css/custom.css`, the Product Document Template, and the `.claude/CLAUDE.md`
template are copied at **scaffold time only** — existing projects apply those
three by hand. Add the mobile-image rule to `custom.css`:

```css
.markdown img[src*="/mobile/"] {
	display: block;
	width: 50%;
	margin-left: auto;
	margin-right: auto;
}

@media (max-width: 996px) {
	.markdown img[src*="/mobile/"] {
		width: 100%;
	}
}
```

Existing docs keep working unchanged; renumbering old scenarios and adding a
responsive section are optional catch-up edits.

## 0.4.0

Adds **prototype-flow evidence** to the Figma pipeline, a **rewritten Product
Document Template**, and a maintainer **`/release`** runbook.

### `lore:figma-to-doc`: read prototype flows & interactions as navigation evidence

- **What changed.** The skill now fetches the file's prototype wiring —
  `flowStartingPoints` (per flow) and each frame's `interactions[]` — from the
  same node call it already makes for annotations, and uses it as the
  machine-readable source for each scenario's **Main Flow** instead of guessing
  the flow from frame names/order. Flow and interaction counts are recorded in
  the source census (even when zero), and any section with ≥ 2 interaction edges
  gets a **Mermaid flow diagram**.
- **Deliberate exclusions.** The legacy `transitionNodeID` / `transitionDuration`
  / `transitionEasing` fields and `prototypeStartNodeID` are ignored (they carry
  only partial or deprecated wiring), and **animation timing** (duration, easing,
  transition-animation type) is dropped as presentation noise — only the
  *navigation meaning* is kept (e.g. an overlay transition ⇒ a dialog).
- **Conflict rule.** Prototype wiring is treated as design intent, not confirmed
  behavior: where an interaction edge contradicts a Dev-Mode annotation, the
  annotation wins and the divergence is reported.
- Docs synced (EN + FA `from-figma` guide).

### Rewritten Product Document Template

- The `templates/docs-layer/docs-template/Product Document Template.md` is
  restructured around researched living-spec / documentation best practices, and
  every skill's reference example + DoD wording is aligned to match.

### Maintainer `/release` command

- Adds the interactive, gated `/release` runbook (ask version → bump all strings →
  PR → tag → GitHub Release → post-tag redeploy + verify live badge).

### Docs

- Capitalized the product name **Lore** where it appeared lowercase in prose in
  `README.md` (the `lore:` skill namespace and literal identifiers stay lowercase).

## 0.3.3

Fixes a visible **RTL styling bug** in the Docusaurus viewer for right-to-left
locales (e.g. Persian).

### RTL: stop `rtlcss` from double-flipping `custom-rtl.css`

- **The bug.** For RTL locales Docusaurus runs the `rtlcss` PostCSS plugin over
  the whole CSS bundle, auto-mirroring physical `left`/`right` values. But
  `templates/rtl-assets/src/css/custom-rtl.css` already authored its rules with
  the **final, post-RTL** physical values inside `html[dir='rtl']` selectors — so
  `rtlcss` flipped them a second time and broke them. Observed in a built RTL
  project: table cells went `text-align:left`, admonition accent borders landed
  on the wrong (left) side, and `.flow-step-number` / `.error-item` offsets
  mirrored incorrectly.
- **The fix.** All directional `html[dir='rtl']` rules are now wrapped in a
  `/*rtl:begin:ignore*/ … /*rtl:end:ignore*/` block so `rtlcss` leaves them
  exactly as authored. The non-directional parts (font-face, fonts, font-size)
  stay outside the block. A header comment documents the gotcha inline so it
  travels with the template to every consuming project.
- **Verified** against a real `fa` build: `table th/td → text-align:right`,
  `.flow-step-number → margin-left:1rem`, `.theme-admonition` accent on
  `border-right-width`, `.error-item → border-right` — all correct, whole site
  builds clean.

## 0.3.2

Fixes a real `lore:figma-to-doc` defect — **Dev-Mode annotations were silently
skipped** — and adds a structural rule for **splitting oversized pages**, plus
speed/quality improvements to the Figma pipeline.

### Figma annotations: correct source + non-skippable evidence

- **Read the real annotations.** Lore previously treated "annotations" as a scan
  for `type: "TEXT"` nodes — but those are design copy. Figma's actual Dev-Mode
  annotations are a first-class **`annotations` property on a node** (`notes` /
  `pinned`), returned by `GET /v1/files/{key}/nodes` with the `file_content:read`
  scope. On files using the real feature, the old approach found nothing and moved
  on. `lore:figma-to-doc` and `lore:figma-extractor` now read the `annotations`
  property; the TEXT-node scan remains only as a clearly-labelled legacy fallback.
- **Annotation & Comment Census (auditable evidence).** The skill now writes a
  census to `.claude/sources/figma-{key}-census.md` — counts, the raw comments and
  annotations, and a coverage map linking each extracted business rule to the doc
  file+section that reflects it. The zero case is explicit ("confirmed none
  present"), so a skipped fetch can't hide as "nothing found."
- **Double-checked in the validator and reviewer.** `lore:doc-validator` and
  `lore:doc-reviewer` now BLOCK (§0) when Figma was the source but the census is
  missing, or when any annotation/comment business rule in the coverage map isn't
  reflected in the docs.

### Multi-page section split rule (§2)

- A new template-`CLAUDE.md` §2 rule: split a section into an overview `index.md` +
  cross-linked sibling sub-pages when it would exceed **more than 6 scenarios or
  more than 3000 words** (whichever first). The validator/reviewer flag an un-split
  oversized page as a **warning**. The `sidebars.ts` template, the document template,
  and all three producer skills reference the rule by section number (Rule 4).

### figma-to-doc speed & quality

- **Scoped node fetches** (explicit `ids=` + deliberate `depth`) instead of
  whole-file walks — the same scoped call returns the `annotations` property and the
  frames, so one fetch serves both.
- **Batched multi-id image export** (`/v1/images/{key}?ids=a,b,c`) with concurrent
  downloads; **cheap re-runs** by reading the existing census first; **dedup with
  preserved provenance** so source refs survive into the coverage map.

## 0.3.1

Keeps the **authoring tooling out of the published documentation** and lets a
live run go **uninterrupted**. Both come from real `lore:site-to-doc` usage:
generated docs were leaking internal references (scenario-script paths,
observed-issue paths, a `CLAUDE.md §3` citation), and every browser step prompted
for permission.

### Rule 5 — Reader-Facing Output (new BLOCKING rule)

- **No tooling leakage in `docs/`.** A new global rule in the template `CLAUDE.md`
  forbids any reference to Claude/Anthropic, the Lore plugin or its `lore:*`
  skills/subagents, the browser automation, or internal `.claude/` artifacts/paths
  in reader-facing documentation. Config facts (trusted sources §1, roles §3) are
  stated directly, never cited by section number or path. The in-chat Final Report
  (§8) is a process deliverable for the user and is exempt — and is never written
  into a doc file.
- **New enforcement hook `check-no-tooling-refs.sh`** (PostToolUse: Write|Edit,
  BLOCKING exit 2) deterministically blocks `docs/` markdown/MDX containing a
  `.claude/` path, a `CLAUDE.md` citation, or the `lore:` namespace. It ships with
  the plugin, so it reaches already-scaffolded repos on `/plugin update`. Same
  project-root scoping and `.claude/`/`templates/`/`_templates/` carve-out as the
  other hooks; `lore:` matching requires a non-alphanumeric boundary so "folklore:"
  is not a false positive.
- **Validator + reviewer gates.** `lore:doc-validator` greps produced docs for the
  forbidden tokens and reports matches as a blocking §6/Rule 5 failure;
  `lore:doc-reviewer` gains a Rule 5 row in its checklist, report, and blocking set.
- **Cleaned the examples and the starter home page** that were modeling the leak:
  the embedded Final Report is removed from the three skill examples (it belongs in
  chat, not the doc), and `docs/intro.md` no longer cites `.claude/CLAUDE.md` or
  lists `lore:*` skills.

### site-to-doc

- **Run mode (pre-flight).** Before any browsing, the skill asks once whether to
  approve each browser action or run uninterrupted. For uninterrupted runs it
  offers to allowlist the Playwright MCP server (`mcp__playwright`) in project
  settings — one approval that also covers the delegated `lore:site-explorer`
  subagent — removable later via `/permissions`.
- **Scenario script is internal-only.** The skill now explicitly forbids surfacing
  the scenario script, its `.claude/scenarios/...` path, or the
  `.claude/observed-issues/...` sidecar anywhere in the published docs (Rule 5); the
  flow reaches readers only as product-facing prose in the Scenarios section. The
  pre-flight also names the two modes — full-page documentation (no user scenario)
  and a specific scenario — and the script stays an internal re-run aid in both.

## 0.3.0

Makes the live-observation run double as a **free QA pass**: the anomalies
`lore:site-to-doc` already notices are now consolidated into ready-to-file bug
drafts instead of staying buried as inline `⚠️` flags.

### site-to-doc

- **Observed-issue bug drafts.** After a scenario run, product defects from the
  `lore:site-explorer` summary — unexpected/undocumented behavior, flagged
  design-vs-reality discrepancies, and failed steps that are genuine defects — are
  consolidated into a sidecar file `.claude/observed-issues/{date}-{slug}.md`,
  one structured draft each (title, type, severity, expected/actual, repro,
  screenshot ref, environment). Scenario-authoring failures (bad selector, your
  own timeout) are explicitly excluded. If nothing qualifies, the run notes "none
  observed" and writes no file.
- **Optional GitHub filing.** When `gh` is installed, authenticated, and the repo
  has a GitHub remote, the skill offers — once, never automatically — to file the
  drafts as issues via `gh issue create`. Default stays drafts-only; filing needs
  explicit confirmation each run. GitHub only; screenshots stay as repo-relative
  paths (no binary upload). The sidecar lives under `.claude/`, inside the hooks'
  existing scope carve-out, and carries the same credential discipline as the
  Login Checkpoint (no secrets, tokens, or absolute paths in a draft).
- **`lore:site-explorer`** now records expected-vs-actual + the originating step
  for each unexpected behavior, and labels failed steps as product defect vs.
  scenario/selector error, so drafting is accurate.

### skills

- Added `argument-hint` to all four skills (`figma-to-doc`, `brief-to-doc`,
  `site-to-doc`, `doc-reviewer`) for input autocomplete.

## 0.2.0

Turns `lore:site-to-doc` from a manual checklist into an **executable scenario
runner**. The skill now drives a real browser to walk a user-defined scenario
step by step, capture a screenshot at each step, and read exact UI text from the
page — instead of assuming the user navigates and screenshots by hand.

### site-to-doc (rewrite)

- **Browser automation via Playwright MCP.** The skill runs scenarios through the
  `@playwright/mcp` server. Pre-Flight now blocks until the browser tools are
  reachable and gives the one-line `claude mcp add playwright …` install command
  if they are not. A degraded main-context fallback is documented for
  environments where a subagent can't reach the tools.
- **New `lore:site-explorer` subagent.** Mirrors `lore:figma-extractor`: it does
  the heavy, context-bloating browsing (drives the browser, walks each step,
  saves screenshots to disk, reads verbatim UI text from the accessibility
  snapshot) and returns a compact summary, keeping the main context clean.
- **Re-runnable scenario scripts.** Scenarios are saved as YAML under
  `.claude/scenarios/{feature}.yaml`, so updating docs after the product changes
  is a cheap targeted re-run rather than a fresh manual pass.
- **Login Checkpoint (auth).** "Human logs in once, automation continues":
  the user logs in manually in the headed browser (2FA/SSO fine), the session
  persists in Playwright MCP's profile, and later runs skip login. Optional
  storage-state export to `.claude/.auth/` (git-ignored), treated as a secret —
  a password is never typed into the chat or read by the model.
- **Token economy.** Navigation and text capture use the accessibility snapshot,
  not screenshots; screenshots are saved to disk only (never returned to
  context); heavy browsing is delegated to the subagent; a default budget of
  ~3 scenarios / ~10 pages per run keeps cost predictable.
- **Deterministic capture.** Fixed `1280×720` viewport (optional `390×844` mobile
  preset for responsive web), `{feature}-{NN}-{state}.png` naming, viewport shots
  by default, and stability waits instead of blind sleeps.

### Templates / docs

- Template `CLAUDE.md` lists `lore:site-explorer`; the §0 Live-Product row now
  reads "browser automation, scenario scripts, screenshots".
- `docusaurus-base/.gitignore` ignores `.claude/.auth/`.
- README documents the Playwright MCP prerequisite and the new subagent.

### Out of scope (noted)

- Native mobile apps remain unsupported here (a future `app-to-doc` skill);
  documenting a web product's mobile/responsive **viewport** is supported.

## 0.1.0

First public (**beta**) release. Versioning was restarted at `0.x` to reflect
that the project, while feature-complete end-to-end, is not yet considered
mature for general use; the earlier internal `1.x` line remains in git history.

This release pairs the full documentation factory (the `/lore:init` scaffold
wizard, the figma/brief/site-to-doc skills, the DoD reviewer and supporting
subagents) with the correctness and robustness work below: enforcement-layer
fixes, distribution hygiene, and the first automated test suite.

### Hooks (enforcement)

- **Project-relative scoping.** Hooks now resolve paths against the project root
  (`CLAUDE_PROJECT_DIR`, else the payload `cwd`) instead of matching `/docs/`
  anywhere in the absolute path — fixes false blocks when a project lives under a
  `…/docs/…` ancestor.
- **Explicit scope carve-out** for `.claude/`, `templates/`, and `_templates/`
  (previously only documented, not implemented).
- **jq is no longer a silent hard dependency.** Extraction falls back jq →
  python3 → sed, and warns loudly (non-blocking) if a payload truly can't be
  parsed, instead of silently disabling enforcement.
- **MDX coverage.** `check-image-path.sh` now also blocks `/static/img/`
  references (and `src="/static/img/"`) in `.mdx`, matching the frontmatter hook.
- **Stop hook hardened.** `verify-docs.sh` now blocks (exit 2) on images under
  `docs/` and on `/static/img/` references, honors `stop_hook_active` to avoid
  loops, `cd`s to the project root, and no longer breaks on filenames with
  spaces or `.js` config variants. Orphan-image detection stays a warning.
- **Frontmatter robustness.** Tolerates CRLF and a UTF-8 BOM, requires a closing
  `---` fence (distinct message), and anchors required keys at column 0.

### Scaffold / detection

- **`.claude/lore.json` project marker** written by `/lore:init` (and
  backfilled by `/lore:config`) records scaffold version, language, and
  Docusaurus state. `detect-project.sh` keys off it; a bare `.claude/` directory
  is no longer misclassified as a Lore docs project.
- `scaffold.sh` reports the layer it was applying if it fails mid-copy.

### Commands / skills / agents

- Removed the broken `$(dirname "$0")` plugin-root fallback from `/lore:init`,
  `/lore:config`, `/lore:add-docusaurus` (use `CLAUDE_PLUGIN_ROOT` → glob → ask).
- Fixed the figma-to-doc Pre-Flight step numbering (was "ALL 5 steps" over 4).
- Localized hard-coded Persian: placeholders/examples now follow the project's
  documentation language (§7); Persian samples are explicitly labeled.
- Added Figma credentials guidance (`FIGMA_TOKEN` / MCP; never persist the token)
  to the figma skill and extractor; removed dangling "lesson #N" citations.
- `npm run build` checks in `lore:doc-reviewer` / `lore:doc-validator` are now
  conditional on Docusaurus being installed (docs-only projects can pass review).
- Constrained `lore:doc-validator`'s Bash use to read-only / build commands.
- Added the four `examples/` reference docs the skills pointed to; fixed the
  dangling `SETUP.md` references in the Docusaurus templates.

### Templates

- RTL fonts are now declared with relative `@font-face` URLs inside
  `custom-rtl.css` (webpack-hashed), fixing 404s under a non-root `baseUrl`
  (e.g. GitHub Pages). Removed `static/css/fonts.css` and the root-absolute
  `@import`.
- Replaced the dead v1-era `.admonition-note` RTL rule with the Docusaurus v3
  `.theme-admonition` selector; removed dead inline-style attribute selectors.
- New project-root `README.md` in the docs layer (Rule 2 referenced a file the
  scaffold never created).

### Distribution

- Added `LICENSE` (MIT) and a SIL OFL 1.1 notice for the bundled Vazirmatn font.
- `plugin.json` now carries `license`, `homepage`, and `repository`.
- Consolidated install/update commands into the README as the single source of
  truth; corrected the unsupported "consumers can pin a version" claim.

### Testing / CI

- New `tests/run-tests.sh` (POSIX, no framework): hook payload fixtures →
  exit-code/stderr assertions, plus `detect-project.sh` and `scaffold.sh` smoke
  checks.
- New GitHub Actions workflow: shellcheck, manifest validation, the hook tests,
  and a scaffold-and-`npm run build` smoke test against the latest Docusaurus.

## Earlier history

Development prior to `0.1.0` (including the former internal `1.x` line) is
pre-changelog. See the git history for details (fetch-latest Docusaurus install,
Vazirmatn font, host-neutral config, reviewer rename, template restructure).
