# Changelog

All notable changes to the Lore plugin are documented here. Versioning is
[semantic](https://semver.org); the source of truth for the current version is
`plugins/lore/.claude-plugin/plugin.json`. Consumers update with
`/plugin marketplace update lore-marketplace` then `/plugin update lore@lore-marketplace`.

Lore is **pre-1.0**: minor releases may include breaking changes until `1.0.0`,
which is reserved for the first mature, general-use release.

## 0.4.0

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
