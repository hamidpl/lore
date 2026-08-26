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
  hooks/                           # hooks.json + 10 shell scripts (output enforcement + evidence gates + methodology sync)
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

Since 0.10.0 the fixing has an owner of its own: **`lore:doc-reviser`**, a subagent with `Read, Edit, Grep, Glob` and nothing else, that applies the validator's `mechanical`/`content` findings as one batch at the `Targets` the report names. The design follows the Aug-2026 research (local, `research/`): revision by the author's own context breaks ~31% of previously-correct content per round, *narrower* one-at-a-time feedback breaks *more* (32% at one finding per round vs 19% at four), and a separate literal reviser cut that break rate by about two-thirds. So: batch the *what*, constrain the *where*, and never let the fixer fetch — the one defect it then cannot introduce is a fabricated receipt. Findings that need new evidence go back to extraction; findings that need a product decision go to the user; a reviser that rejects a fix against the evidence is a disagreement the user settles. Every `Required Action` therefore carries `Class / Targets / Evidence / Counter / Severity / Fix` (canonical in `skills/doc-reviewer/SKILL.md`), and a blocking finding with no `Evidence:` does not count.

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

Hooks in `plugins/lore/hooks/hooks.json` split into two families: **output enforcers** (is the markdown shaped right?) and **evidence enforcers** (did the work actually happen?).

### Output enforcers

- **`check-image-path.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): images must be in `static/img/`, markdown/MDX refs must use `/img/` (never `/static/img/`), images must never be placed in `docs/`, and `/mobile/` screenshots must be embedded with a raw `<img …/>` tag — markdown `![…](…/mobile/…)` refs are blocked because the Docusaurus build rewrites markdown-embedded images to hashed `/assets/images/` URLs, stripping the `/mobile/` path the half-width CSS keys on.
- **`check-frontmatter.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): every `docs/` markdown/MDX must have a closed YAML frontmatter block with 4 keys: `sidebar_position`, `title`, `description`, `tags` (tolerant of CRLF/BOM).
- **`check-no-tooling-refs.sh`** (PostToolUse: Write|Edit, BLOCKING exit 2): `docs/` markdown/MDX must not reference the authoring tooling — blocks `.claude/` paths, `CLAUDE.md` citations, and the `lore:` skill/subagent namespace (Rule 5 / §6). `lore:` requires a non-alphanumeric boundary so prose like "folklore:" is not a false positive.
- **`verify-docs.sh`** (Stop): BLOCKS (exit 2) on images under `docs/`, `/static/img/` refs, and markdown-embedded `/mobile/` images; WARNS about orphan images. Honors `stop_hook_active` to avoid loops. Also carries the two **process gates** below.
- **`sync-lore-files.sh`** (SessionStart: startup|resume|clear|compact, non-blocking): keeps the plugin-owned `.claude/lore-methodology.md` in a consuming repo in sync with the installed plugin (an extensible `SOURCE|DEST|MODE` manifest; `owned` = silent `cmp`/`cp` overwrite + a one-line `systemMessage` notice, `notify-only` = report drift, never overwrite). Guarded: acts only in a repo whose `.claude/CLAUDE.md` imports the methodology file, so it never writes into non-Lore repos. Source path is `${CLAUDE_PLUGIN_ROOT}/templates/docs-layer/.claude/lore-methodology.md`. This is how always-on rule updates reach existing projects.

### Evidence enforcers (DoD §0.1–§0.4)

These exist because a §0 obligation used to be discharged by *writing a sentence*: `nothing relevant — confirmed searched` is byte-identical whether the source was read or never touched, and the agent that skipped the work authors the sentence. The fix is to make claims **falsifiable against artifacts a hook wrote**.

- **`record-evidence.sh`** (PostToolUse: `WebFetch|Task|Bash|Write|Edit|mcp__.*(playwright|browser|chrome|puppeteer|fetch).*`, never blocks): appends one TAB-separated line per fetch / subagent run to `.claude/sources/.evidence-log` — `iso8601, tool, detail, tier, [agent], [sha]`. The log has **one writer**, `lore_append_evidence` in `lib/common.sh`; `figma-probe.sh` goes through it too, adding `status=NNN` to the detail and the sha-256 of the saved payload as field 6. Field 5 is the `agent_id` the runtime puts on a hook payload inside a subagent (Claude Code ≥ 2.1.69) — who fetched — so a fetch by one of several extraction workers is attributable. Readers use `NF >= 4`; 4-, 5- and 6-field lines are read alike.

  **Tiers are the load-bearing part.** `verified` means a fetching tool actually ran (WebFetch, browser navigation, a subagent, and `figma-probe.sh` appending its own entry once it has an HTTP status). `mentioned` means a URL merely appeared inside a Bash command — `grep -rn "https://x" ./notes` contacted nothing, and a failed `curl` contacted nothing either. `check-census.sh` accepts only `verified` as proof a source was read. Without the split, ordinary work manufactured receipts. Lines with no 4th field predate tiering and are read as `verified`.

  Values come from tool input, so they are sanitised before writing: for every tool but Bash only the first line is kept (an embedded newline used to append a second, forged entry), and all control characters are stripped per line (an embedded tab forged the tier column).

- **`check-citation-loss.sh`** (PreToolUse: `Edit|Write`, BLOCKING exit 2): an edit to a `docs/` page that would remove a URL whose **host has a `verified` fetch** in the evidence log is denied, with a message that says to move the citation or report the removal to the user. This is the one revision damage class the research found *no* prompt-level mitigation cures — citation faithfulness fell by up to two-thirds under multi-turn revision even with a dedicated reviser — and it is deterministic here only because the log is hook-written. Judged against the whole file (a citation moved between sections survives; `replace_all` scales the count); a `mentioned`-only or unknown host is not a receipt and is not gated.
- **`check-census.sh`** — the single place every census rule lives, in **two modes**:
  - *(default)* PostToolUse Write|Edit, BLOCKING exit 2 — validates **shape**: the `## Run contract` block exists (§0.4); every `[t#]` trusted-source row carries an HTTP status **and** a `.claude/sources/raw/` path, whether it found something or nothing (§0.1 — receipts used to be checked only on zero-case rows, so the majority of rows went unexamined); every zero-case line carries the same receipt; `corroboration=RAW-HAS-…` anywhere is a blocking parser failure (§0.2); every cited raw payload exists and is non-empty; every claimed URL's host appears in `.evidence-log` as a **verified** fetch; cited screenshots exist. Fenced blocks are skipped — a quoted format example is not a claim.
  - `--complete <file>`, invoked by `verify-docs.sh` at Stop, BLOCKING exit 2 — validates **completeness**: a `site-*` census has `## Observation coverage` with at least one `[o#]` row; a `figma-*` census has a `## Counts` row carrying a **number** for each manifest source type.

  **Why the split.** Completeness used to be enforced at write time, which blocked the exact pre-flight census the skills prescribe (`site-to-doc:30`, `figma-to-doc:140`). The cheapest way out of that block was a placeholder — an empty `## Observation coverage` heading, or one prose line naming the six Figma source types — and the placeholder then satisfied the check **for the rest of the run**, because nothing re-examined it. The gate taught the model to disarm the gate. Shape at write, completeness at Stop.
- **`record-validator-run.sh`** (SubagentStop: `lore:doc-validator`, never blocks): writes `.claude/sources/.validator-receipt` — line 1 the timestamp and the verdict parsed from the subagent's own final message (`APPROVED` / `APPROVED WITH WARNINGS` / `BLOCKED` / `UNKNOWN`), line 2 the `format\t2` marker, then one `file` line per `docs/**/*.md|mdx` carrying a **hook-computed sha-256** and a coverage status. It also appends one line per run to `.validator-history` (append-only) and consumes any standing waiver.

  **Why the receipt carries scope, not just a verdict.** A verdict alone cannot distinguish "I checked these two strings" from "I audited the tree", so a narrow APPROVED silently blessed everything — and the Stop gate, having only an mtime to compare, charged a full re-validation round for a `touch`. Coverage is therefore per file, per digest: `reviewed` (named in the report's `Files reviewed:` line), `inherited` (unchanged since a previous **green** receipt covered it — never inherited from a BLOCKED run, which would launder it), `waived`, or `uncovered`. **The digest snapshot alone never grants coverage** — that is the whole point of `uncovered` — so a file the validator never opened stays unvalidated no matter how many green runs pass over it. A report with no `Files reviewed:` line blesses the whole snapshot, preserving v1 semantics: absence widens, never blocks. With no sha tool on PATH the hook writes the old one-line receipt and the gate falls back to mtime.
- **`guard-reviser-edit.sh`** (PreToolUse: `Edit|Write`, BLOCKING exit 2, **only** when the payload's `agent_type` is `lore:doc-reviser`): denies a `Write`, a `replace_all`, or an edit to any path outside `docs/`. The reviser's agent file says all three; this is what makes them true. Without `agent_type` on the payload (Claude Code < 2.1.69) it exits 0 and the prose governs. The same `SubagentStop` hook that records validator runs records each reviser round as a `REVISED` line in `.validator-history` (parsed from the reviser's `Files edited:` line, which must open a line), so the Stop gate's circuit-breaker message reports validator runs and reviser rounds separately.
- **`guard-under-review.sh`** (PreToolUse: `Edit|Write|Task`, PostToolUse: `Task`, BLOCKING exit 2 on edits): while the standing verdict in `.validator-receipt` is `BLOCKED`, an edit to `docs/` is denied unless it happens inside a `lore:doc-reviser` run. **Why it exists:** in the first two measured runs of the reviser rule the main agent read it and then applied the batch itself — a routing rule only the model follows is followed when convenient. **How "inside a reviser run" is known:** not from `agent_type` on the edit's payload (absent on tool hooks in Claude Code 2.1.52, measured) but by bracketing the reviser's *invocation* — the `Task` PreToolUse with `subagent_type: lore:doc-reviser` writes `.claude/sources/.reviser-active`, the Task's PostToolUse and the reviser's SubagentStop remove it, and the marker expires after 30 minutes so a crashed run cannot hold the door open. Drafting (no receipt), post-green edits (digest gate) and everything outside `docs/` (the census is the `evidence`-class fix) are untouched.
- **`require-worker-evidence.sh`** (SubagentStop: `lore:figma-extractor`, BLOCKING exit 2 — which *re-prompts the worker*, not the main agent): a worker may not finish while its summary carries no `RECEIPT` line naming a raw payload that exists on disk, and no fetch attributed to it in the evidence log. This is what makes **Figma extraction fan-out** safe: the merge is deterministic (concatenate receipts, sum counts, one row per payload path, disagreements become `[n#]` anomaly rows, a missing scope is re-run sequentially — never filled from memory), so the only way a fabricated count could enter the census is a worker that returns one, and this hook returns that worker to work. Attribution by `agent_id` (field 5 of the log) is used when the runtime provides it (≥ 2.1.69); on 2.1.52 the worker's own `RECEIPT` claims are falsified against disk and log instead. Fan-out is **Figma-only and opt-in** (a user instruction, or a very large inventory — heuristic ≥ 4 sections and ≥ 48 frames; ≤ 4 workers; disjoint `ids=` sets — `figma-probe.sh` names raw payloads per id-set, so disjoint scopes cannot overwrite each other's receipts); `lore:site-explorer` stays sequential because every site worker would share the session's single browser. **Why opt-in:** the F2-2 mechanics run (synthetic 3-section × 12-frame file, stubbed API with 0.8 s latency) showed three workers *slower* than one pass — 877 s vs 459 s — at 2.7× the cost, with every mechanic working (receipts per worker, deterministic merge, census complete, counts summed correctly). At that size a worker's turns dominate, not the API; the regime where fan-out pays (image export and node fetches on a very large file) is unmeasured, so the default is the cheaper, measured path and a fanned-out run reports its wall-clock so the heuristic can be corrected.
- **`remind-census.sh`** (PreToolUse: Write, never blocks): when a *new* `docs/` page is created and no census exists, injects `additionalContext` restating the §0 obligations at the moment of the action. Deliberately advisory — denying would false-block `/lore:init` (which scaffolds `docs/intro.md`) and hand edits.
- **`remind-mass-edit.sh`** (PreToolUse: `Edit|Bash`, never blocks): fires on a tree-wide identical edit of `docs/` — an `Edit` with `replace_all`, or an in-place `sed`/`perl` naming `docs/` — and injects the incident-derived checklist (fidelity-promise wording, text whose subject *is* the replaced word, rows that become duplicates, Unicode variants the replacement misses, and the reminder that a fix is a new claim). **This is the one damage class no output check can see**: nothing is mis-typed, every changed line is individually correct, and only the surrounding sentence became false — which is why the only useful moment is before the operation. Advisory for the same reason `remind-census.sh` is: whether a given bulk edit is risky is exactly the judgement that went wrong in the incident, so a hook must not pretend to make it.
- **`verify-docs.sh` process gates** (Stop, BLOCKING): (a) **the session produced no census at all** — every §0 rule is checked against that file and `check-census.sh` only fires when one is written, so a run that never writes one skips all of them at once; requiring the artifact is what makes the rest of the evidence layer reachable (this is the gap that made 0.7.0's headline guarantee untrue); (b) each census fails `check-census.sh --complete`; (c) any `[u#]` run-contract row whose status field is not exactly `satisfied` (with a non-empty evidence cell) or `waived` (§0.4); (d) no receipt at all, a non-green verdict, or documentation whose **content** differs from what the last green run judged.

  **(d) compares digests, not mtimes, and routes what it finds to the user.** The old gate blocked on `find docs -newer <receipt>`, which is wrong in both directions: a `git pull`, a rebase or an editor save that restores identical bytes forced a whole re-validation round, while the gate's only vocabulary for a real change was "re-run it" — so a one-word fix and a 154-hit tree-wide replacement got the same response, and neither reached the user's judgement. Now an unchanged rewrite is a non-event, and any real change (edited / new / deleted / `uncovered`) blocks with a message telling the model to **report the change and its risk and ask**, offering exactly two ways forward: a scoped re-validation of those files, or a user-approved waiver. The `stop_hook_active` loop guard is what makes asking possible — the first Stop blocks, the model's question reaches the user, the next Stop passes.

  **The waiver (`.claude/sources/.validation-waiver`) is model-written, user-approved, and scoped by digest.** Line 1 is `ts<TAB>the approved reason`; each further line is `<sha-256 of the file's CURRENT content><TAB><path>` (the literal `deleted` for a removed file). It is accepted only when every changed file is covered at its exact current digest, so **a later edit silently invalidates it** — an approval can never stretch to cover a change the user never saw. It cannot launder a non-green verdict (the verdict is checked first), and a subsequent validator run folds matching entries into the receipt as `waived` and deletes it. That it is model-written is consistent with the threat model: like `waived (user approved)` in §0.4, it records a decision, and the guard is that producing it dishonestly takes a deliberate act, not an accident. Both fire **only when `.claude/sources/` exists AND this session produced documentation** — the session id must appear in `.claude/sources/.docs-touched`. That marker is git-ignored, so **its absence means "no session here has produced docs", never "unknown, therefore block"**: reading it the other way blocked every session in every clone of a Lore repo. Hand-maintained docs trees are never gated.

  Status matching is **whole-field, not substring**. `grep -v satisfied` filtered out `not satisfied` and `unsatisfied` — the exact phrasing §0.4's own wording primes the model to write — so the gate passed the failure it was built to catch. The same defect existed in `record-validator-run.sh`'s verdict parsing (a report saying "nothing was BLOCKED" became a BLOCKED verdict); both now require the token to open a line.

**Known limits** (state these when they come up): a source fetched before this shipped is not in the log, so the first post-upgrade run re-fetches; URL matching is by host, which is deliberately permissive to keep false blocks near zero. **Freshness is recorded, not gated.** A receipt proves a fetch happened, and since the probe writes `status=` and the payload's sha-256 into the log line, it also proves *what* came back — but nothing re-checks a source between fetch and delivery. A Stop-time freshness gate (re-hash cited payloads, re-probe `[t#]` URLs, block with the same report-and-ask shape as the digest gate) was designed and deliberately **deferred** (roadmap Phase D): it costs network at every Stop, a local re-hash detects only tampering, and no measurement of how often sources actually drift between fetch and delivery exists yet — the brief-based F2 fixtures cannot produce one (their sources are local files). The recording half is what a later gate needs and is already in place; do not add the gate without the drift measurement.

**Project scoping (every hook, no exceptions).** A plugin is installed per *user*, so every hook runs in whatever repo the session happens to be in. **All ten hooks therefore guard on the Lore marker** — a `.claude/CLAUDE.md` containing `@lore-methodology.md` — and exit 0 immediately otherwise. This is not an optimisation. Without it, installing Lore imposed its Definition of Done on unrelated projects: any repo keeping plain markdown or an image under `docs/` had those writes blocked, and `verify-docs.sh` blocked **every turn** there. The rules in this plugin are Lore's DoD, not universal truth, and a repo that never opted in must be untouched.

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
