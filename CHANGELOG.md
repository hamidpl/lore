# Changelog

All notable changes to the Lore plugin are documented here. Versioning is
[semantic](https://semver.org); the source of truth for the current version is
`plugins/lore/.claude-plugin/plugin.json`. Consumers update with
`/plugin marketplace update lore-marketplace` then `/plugin update lore@lore-marketplace`.

Lore is **pre-1.0**: minor releases may include breaking changes until `1.0.0`,
which is reserved for the first mature, general-use release.

## 0.9.0 (unreleased)

**The validation loop was self-feeding, and the tooling could not tell.** One real
delivery took **seven** validation rounds — and four of them found defects that had not
existed the round before. The diagnosis that matters: this is not a validator that keeps
complaining. `lore:doc-validator` is read-only and changes nothing; the loop lives in the
*fixing*, which happens under time pressure, one edit at a time, sometimes while a round
is still in flight — and a fix is a claim that passed none of the checks the original
passed.

### The receipt now records what was validated, not just that something was

`.validator-receipt` carried `(timestamp, verdict)`. So a narrow APPROVED — "check these
two strings" — was indistinguishable from a full audit, and the Stop gate, having only an
mtime to compare, had exactly one response to any later change: *re-run it*. A one-word
typo fix and a 154-hit tree-wide replacement got the same treatment, and neither reached
the user's judgement.

The receipt is now a hook-written per-file snapshot: sha-256 of every `docs/` page plus a
coverage status — `reviewed` (named in the report's new `Files reviewed:` line),
`inherited` (unchanged since a previous **green** receipt; never inherited from a BLOCKED
run), `waived`, or `uncovered`. **The digest snapshot alone never grants coverage**: a
file the validator never opened stays `uncovered` no matter how many green runs pass over
it. Line 1 keeps the old `ts<TAB>verdict` shape, so an old reader still works; with no
sha tool on PATH the hook writes the v1 receipt and the gate falls back to mtime.

### The Stop gate compares content, and asks instead of looping

`find docs -newer <receipt>` was wrong in both directions. A `git pull`, a rebase or an
editor save that restores identical bytes forced a whole re-validation round for nothing;
and a real change only ever produced "re-run it". Now:

- an unchanged rewrite is a **non-event** — the false blocks are gone;
- a real change (edited / new / deleted / uncovered) blocks with a message that names the
  files and tells the model to **report the change and its risk to the user and ask** —
  offering a scoped re-validation of exactly those files, or a **user-approved waiver**.

The waiver (`.claude/sources/.validation-waiver`) names each file at its **exact current
digest**, so a later edit silently invalidates it: an approval can never stretch to cover
a change the user never saw. It cannot launder a non-green verdict, and the next validator
run folds it into the receipt and deletes it.

### The delivery boundary, batched fixes, and a circuit breaker

New in the Auto-Validation Rule (canonical in `lore-methodology.md`): a green verdict
**ends that delivery** — a later edit is the next one; fixes go in as **one batch**
followed by **one** scoped round, and no file is edited while it is under review (the two
rounds that finally came back clean in the real run were the two that did this); and
**two consecutive rounds finding fix-introduced defects means stop and put the decision to
the user**, not open a third. The producer skills' old instruction — *"fix and re-run
until it returns green"* — was itself the loop, and is gone. `.validator-history` is
append-only, so "how many rounds did this take" is now a number rather than a memory.

### Zeros: prove the probe, don't name a flag

Two independent mechanisms made the validator's own searches silently return nothing: the
environment's `grep` skipped the evidence corpus because `raw/` is git-ignored, and some
payloads store text as `\uXXXX` escapes where a raw UTF-8 needle cannot match. Both exit
cleanly with zero hits, and no portable flag fixes both. §0.2 therefore prescribes a
**control needle** — a string already proven present, through the same command over the
same paths — rather than any tool or flag. Note the shape: *the tool enforcing §0.2 was
itself failing §0.2*.

That rule had to land first, because of what it gates: the validator now runs an
always-on **quoted-string provenance sweep** (a fabricated or mis-attributed UI string was
this project's most repeated defect, and was only ever caught when someone asked for it by
hand). A BLOCKING sweep over a broken probe is worse than no sweep — in one round it
nearly condemned a dozen correct strings as fabricated — so "not found" is a verdict only
after the control passes and a tolerant retry (zero-width marks, escape forms, Unicode
variants) still finds nothing.

### Also

- **Nothing under `docs/` is evidence about the product** (new, under §0.1). Citing our
  own normalised output to prove what the product does is how a *correct* sentence got
  "fixed" into a wrong one across 21 pages. And **a fix is a new claim**, carrying the
  same receipt obligation as the claim it replaces.
- **`remind-mass-edit.sh`** (new, advisory): before a tree-wide identical edit of `docs/`,
  injects the checklist the incident produced — fidelity-promise wording, text whose
  subject *is* the replaced word, rows that become duplicates, Unicode variants the
  replacement misses. No output check can see this damage: nothing is mis-typed, every
  changed line is correct, only the surrounding sentence became false.
- **Standing product decisions get a home.** A permanent ruling frozen into a `[u#]` row
  diverged silently months later, because those rows are checked once and never again.
  They now belong in the product layer with their date; `check-census.sh` blocks a
  `Standing:` row that references nothing.
- Findings now carry a provenance label (`pre-existing` / `introduced-since-last-green`),
  which is what separates "the validator keeps complaining" from "our fixes keep breaking
  things" — and feeds the circuit breaker.

### The edge-case sweep now produces a list a designer can act on

`brief-to-doc` already walked the edge-case taxonomy — but it wrote for the wrong reader.
Its output was questions aimed at the document's author, scattered through the scenarios
as `[CLARIFICATION NEEDED]` markers. A designer opening the document found no list of
what still had to be drawn.

Every applicable category now produces **two** things: the marker at the step it belongs
to, *and* a row in the template's new `## States to Design` table — the flat checklist,
with three statuses that separate a design task from a product decision:
`specified — needs design`, `unspecified — needs decision + design`, `designed`.
`figma-to-doc`'s missing-states check feeds the same table instead of only inline markers.

Two things that had to be said explicitly for this to work at all:

- **Naming a required state is not inventing behavior.** The no-invention rule forbids
  writing what the product does in an undescribed state; the table writes none of that —
  it names which state needs designing. Without the carve-out stated in the template,
  the two rules appear to conflict and the table gets left empty.
- **The table is exempt from the ~5-question cap.** Asking costs the user's attention;
  listing costs nothing. Trimming the designer's list to match the number of questions
  asked was the obvious wrong move.

Also fixed: the canonical taxonomy had **no `loading` category**, while `figma-to-doc`
carried its own four-item copy that demanded a loading state. Two lists, silently
diverged, nothing able to catch it. There is now one list, plus a test asserting no skill
re-lists it and that every category a skill names exists in the template.

### Images are compressed before they are committed

There was no image optimization anywhere. Figma exports at `scale=2` (a 1440px frame
lands as 2880px) and Playwright screenshots are raw PNG — and both get committed to the
documentation repo and served by the site, so nothing reclaims that weight later.

`scripts/optimize-images.sh` runs once per run, after every capture has landed.
**Measured on real UI screenshots: 72% smaller, dimensions unchanged, no visible
difference.**

- **One batch, not per image — and not for the obvious reason.** Process startup is
  ~10ms; what per-image really costs is one *agent tool round-trip* each, so forty
  images means forty round-trips instead of one call.
- **The quality floor is the safety property.** `pngquant --quality=65-90` exits 99 and
  leaves the file untouched when it cannot hold the floor, so "don't damage quality" is
  enforced by the tool, not by anyone's judgement. A lossless pass follows. PNG stays
  PNG — WebP would save more but changes every extension, doc reference and census row,
  so it is deferred to its own change.
- **Idempotence is correctness, not speed.** A second lossy pass degrades the file
  again, so the fingerprint of each optimized result is recorded and skipped next time.
  A re-captured screenshot has a new fingerprint and is optimized afresh.

With no optimizer installed it reports `tool=none`, changes nothing, and exits 0 — never
claiming a saving it did not make, and never failing a run over a missing optional
binary. The Stop hook warns (never blocks) about large PNGs that never went through it.

## 0.8.1

**The first release driven by measurement rather than reasoning.** A workflow audit
proposed twenty optimizations. Experiments rejected seventeen of them — two of which
would have opened holes — and a benchmark showed the headline saving of an eighteenth
never materialised. What shipped is the residue that survived: three small changes, each
traceable to a number.

### The validator re-read rules it already had

`doc-validator` opened `.claude/CLAUDE.md` and `.claude/lore-methodology.md` on every run.
Both are already in its context: `CLAUDE.md` `@`-imports the methodology, imports are
expanded at launch, and a non-fork subagent inherits the whole `CLAUDE.md` hierarchy. The
prompt even conceded the point — *"both are in context — but read both files explicitly"*.

Verified before changing: a session scaffolded from the docs layer quoted §0.2's first
bullet with no tool use, and a subagent spawned inside it did the same, reporting it had
the text *"without reading any file"*. Instrumented runs confirm the behaviour changed —
baseline read both files, current reads neither.

⚠️ **This did not reduce total tokens.** Measured: 43,187 → 43,990 (+2%). The ~9k of reads
were genuinely avoided, and the freed budget went to other files instead. Recorded here
because the opposite is the intuitive assumption and it is wrong.

### One malformed command cost an entire batch

Tracing a full run found **12 of 40 tool calls failing**. The mechanism: `test -s X && echo Y`
is rejected as *"multiple operations"* and `wc -w < file` as *"input redirection"* — and
when one call in a parallel batch is rejected, **every sibling issued alongside it is
discarded**. Two malformed commands destroyed eleven healthy ones and produced three
round-trips that gathered nothing.

`doc-validator` now requires one operation per Bash call, no chaining, no `<`. It also
records a rejected command as unrun instead of reissuing it — the same `curl` had been
retried three times.

Measured, same fixture: **154.1 s vs 216.8 s wall-clock, 32 vs 40 tool calls, 6 vs 12
failed calls, 41,467 vs 43,990 tokens.** Zero malformed commands in the post-change run.
Single runs, and duration varied 190–248 s across identical configurations, so treat the
timing as indicative and the counts as firm. **Reasoning turns did not change: 10 → 10.**

### Two maps of the same territory

`lore-methodology.md` carried two canonical-locations tables — one under Rule 4, one under
the DoD declaring *"Nothing else may restate it"* — and two copies of the input-type→skill
table. They are now one each, merged as supersets so no row was lost. This is a
consistency fix, not a saving: it recovers 274 bytes, against the ~400–600 tokens the
audit predicted.

### What was deliberately not done

Stop-gate scoping was the audit's #3 item; `.docs-touched` has exactly one writer
(`Write|Edit`), and its own comment records that it exists so a `git pull` does **not**
gate — inverting it would have let changes arrive unchecked. Evidence-log rotation
contradicts the documented append-only invariant. Dropping the validator's hook-covered
checks assumed hooks had run on those artifacts; `check-census.sh` fires only on write, so
a carried-over census is unvalidated. All three were rejected on evidence, not taste.

### Known, unfixed

`doc-validator.md` calls `lore:doc-reviewer` *"the single source of truth for how to
review"* and gives no path, no env var, and no `Skill` tool to invoke it. Stale plugin
versions persist in the cache — `0.6.3`'s copy still says the canonical rules live in
`CLAUDE.md`, which stopped being true in 0.6.0. Latent while the copies match; live on any
machine mid-upgrade. It is a defect, not an optimization, and needs its own change.

## 0.8.0

**Post-release correctness and the tests that would have caught it.** 0.7.0 shipped the
evidence gates; this is the follow-up the roadmap deferred out of it — the generated-site
defects that predate the release, the hook-layer duplication that let one bug exist in
seven places, and the first tests in this project that check *the model's prescribed
workflow* rather than a hand-written fixture.

### The generated site was never deployable as generated

- **`url` was the framework's own example domain.** Every site Lore scaffolded shipped
  `url: 'https://your-docusaurus-site.example.com'` — the origin of every canonical
  `<link>`, every `og:` tag and every entry in `sitemap.xml`. Wrong, and wrong in a way
  that looks deliberate, so nothing ever flagged it. It is now a `{{SITE_URL}}`
  placeholder the wizard must fill: it **asks** where the docs will be deployed, and
  writes `http://localhost:3000` when the answer is "not yet" — obviously provisional
  beats plausibly wrong.
- **`onBrokenLinks` was `'warn'`.** DoD §6 names the production build as its
  authoritative link check and the install guide repeated that promise, while the build
  went green with dead links in it. Now `'throw'`.

  ⚠️ **Behaviour change for consumer projects.** A site with pre-existing broken links
  will now fail its build. That is the point, but it will surface on the first build
  after a scaffold refresh rather than at a time of your choosing.

### One bug, seven copies

- **`hooks/lib/common.sh`.** The JSON-extraction ladder, project-root resolution, the
  Lore-marker guard and the carve-out were copy-pasted into seven of the nine hooks —
  about a third of the hook layer. They now live in one sourced library. Hooks resolve it
  through `$(dirname "$0")`, never `${CLAUDE_PLUGIN_ROOT}`: `hooks.json` interpolates
  that into the *command string*, which does not guarantee it reaches the hook's
  environment. A test asserts no hook gets this wrong.
- **The text fallback returned the wrong file.** With neither `jq` nor `python3`
  available, `json_field` fell back to `sed -n 's/.*"file_path".*/\1/p`. `.*` is greedy,
  so it returned the **last** match in the payload — the `tool_response` echo rather than
  `tool_input` — on every `Write`, and the `head -n 1` after it was decoration. It now
  anchors to the parent key and takes the first match.
- **…and it could not read a boolean.** `stop_hook_active` is a JSON boolean, and the
  string-only scan returned empty for it. On a machine with no JSON parser, the Stop
  hook's loop guard was silently disabled — the one failure mode that can trap a user in
  a loop. The fallback now reads unquoted scalars.
- `json_field` takes **one** argument (a key path) instead of three dialect-specific
  ones, so a call site can no longer describe the same field three inconsistent ways.

### Statements that contradicted their own implementation

- **Rule 5 claimed a blocking tier it never had.** The methodology listed
  Claude/Anthropic/Playwright alongside `lore:*` and `.claude/` paths as forbidden, while
  both the hook and the validator deliberately treat the former as *warnings* — a product
  may legitimately document an integration. The rule now states the two tiers it actually
  has.
- **`doc-validator` forbade and required the same command.** One bullet granted Bash "for
  `npm run build`" and forbade "any command that modifies the filesystem". The build
  writes `build/` and `.docusaurus/`. Split into a grant and a constraint, with the build
  named as the one explicit carve-out. Its Rule-4 line also still pointed rule citations
  at `CLAUDE.md`, which stopped being where the methodology lives in 0.6.0.
- **`remind-census.sh` stripped every `§`.** The just-in-time reminder — whose entire job
  is to point at §0.1–§0.4 — read `DoD 0`, `CLAUDE.md 1`, `(0.4)`.
- `brief-to-doc` cited "§2 step 6" for the readiness gate, which is step 7.
- `detect-project.sh` called the model-written `.claude/lore.json` "authoritative".

### `scaffold.sh` failed silently

`--target X` with no `--layer` printed `done (layers:)` and exited **0** — a wizard step
that dropped its layer flag reported success over an empty directory. `--target` with no
value died on `shift 2` under `set -e` with no message at all. Both are now exit 2 with
an actionable message, and an unknown layer is rejected during argument parsing rather
than mid-copy (where it triggered a "already-copied files were kept" warning describing
a copy that never began).

### Tests: 173 → 233 assertions

The strategic item, and the reason this release is worth its size. Every defect in the
0.7.0 audit coexisted with a green suite, because each assertion tested a hook against a
fixture written by whoever wrote the hook — so they agreed by construction.

- **The skills' own census skeletons are now parsed out of the `SKILL.md` files and
  checked against what the hooks actually read** — that the `status` cell is in the
  column `verify-docs.sh` reads by position, that every Figma manifest source type has a
  row, that every zero-case phrase a skill teaches is one the hook recognises. This is
  the class of defect that shipped in 0.7.0: a skill prescribing a census its own gate
  rejects.
- **A complete, receipted census per input type** — real raw payloads on disk, real
  `verified` evidence-log entries — proven to pass *both* the write-time and Stop gates.
  Every prior test proved a gate blocks; none proved they can all be satisfied at once.
- **A defect corpus mutated from that same green census, one defect at a time**, so a
  block can only be attributed to the defect introduced. Each mutation is asserted to
  have actually landed first — a `sed` that matches nothing exits 0 and copies the file
  through, after which "it blocks" would have been a lie.
- CI now lints with `shellcheck -x` so the shared library is checked in the context of
  each hook that sources it, and asserts the library ships and is *not* executable.

## 0.7.0

**Evidence gates: a claim now needs a receipt.** Three BLOCKING rules were skipped
in a single real documentation run, and validation passed all three. This release
moves the §0 obligations out of prose and into the deterministic layer.

### Problem

Every §0 obligation was discharged by *writing a sentence*, and no sentence was ever
compared against a machine-observable fact. `nothing relevant — confirmed searched` is
byte-identical whether a source was read or never touched, and the agent that skipped
the work is the one authoring the sentence — so it always passed. Concretely:

1. **Figma annotations were never extracted, and the miss was certified.** The plugin
   hard-coded `annotations[].notes` in five places; the Figma REST API returns the text
   in `label`/`labelMarkdown`, and its own OpenAPI spec declares `AnnotationsTrait` as
   `properties: {}` — the shape is undocumented. The probe returned nothing, and §0's
   explicit-zero rule then dutifully recorded `0 annotations — confirmed none present`.
   The census **laundered a code bug into a certified absence**, deleting every business
   rule the designers had written. A second bug compounded it: `depth=1` was recommended
   for scoping, but annotations hang off deep descendant nodes, so that fetch structurally
   cannot see them.
2. **A trusted source was skipped and the skip was recorded as a finding.** It was assumed
   to need a support session *because of where its link sat in the page footer*, and the
   census row read `nothing relevant — confirmed searched` without a single HTTP request.
3. **An explicit user instruction evaporated.** `site-to-doc` was asked to cover the
   signed-in state; only the guest view was ever observed, and the documentation was
   written from it. Nothing on disk remembered the instruction, and the word "guest" did
   not appear anywhere in the plugin — auth was modelled as an obstacle to get past, not
   as a documented product state. The persistent browser profile actively hides the guest
   view on re-runs, so neither state was reliably captured.

0.6.2 addressed this class with "add a rule + have the validator check it". That is the
approach that leaked here, so this release does not repeat it.

### What changed — four evidence rules

DoD §0 gains four sub-rules (additive; no renumbering), propagated to existing projects
by the `SessionStart` sync hook:

- **§0.1 Evidence, not attestation** — every census row carries a receipt: the probe run,
  its HTTP status, the bytes returned, and the on-disk path of the saved raw payload. The
  words *confirmed / verified / checked* carry no evidentiary weight anywhere.
- **§0.2 Negative-result protocol** — a zero is the cheapest result to produce and the one
  that silently subtracts content. It is valid only beside a successful receipt **and** a
  corroboration by a second, independent method. Raw payload has the data but the parse
  returned 0 → **parser failure, not absence**.
- **§0.3 No assumption about accessibility** — a source may be called login-gated or
  unreachable only on an **observed** status code or auth wall; never inferred from a
  link's position, a name, or a guess.
- **§0.4 Run contract** — explicit user instructions become numbered `[u#]` rows written
  at pre-flight, and delivery is blocked while any row is open.

### Enforcement — the hook layer, not more prose

Hooks can match `WebFetch`, `Task`, `Bash`, MCP tools, and `SubagentStop` by agent type,
which makes the decisive artifact possible: **an evidence log the model does not author.**
It is a guard against a step being skipped, not a tamper-proof record — an agent with shell
access can append to any file. The property it buys is that a source never fetched does not
end up in the log *by accident*, which is the failure mode this release is about.

- `record-evidence.sh` (PostToolUse, never blocks) appends one **tiered** line per fetch and
  subagent run to `.claude/sources/.evidence-log` — see "The evidence log is tiered" below.
- `check-census.sh` owns every census rule, in two modes: as a Write|Edit hook (exit 2) it
  validates **shape** — Run contract present, a receipt on **every** trusted-source row,
  raw payloads that exist and are non-empty, every claimed URL backed by a **verified** fetch
  in the evidence log, cited screenshots on disk, and no zero the raw payload contradicts;
  as `--complete <file>` it is invoked by the Stop hook to validate **completeness** — a site
  census showing at least one observed state, a Figma census carrying a counted row per
  manifest source type.
- `record-validator-run.sh` (SubagentStop, never blocks) records each `lore:doc-validator`
  run and its verdict, matched at the start of a line so report prose cannot set it.
- `remind-census.sh` (PreToolUse, never blocks) injects the §0 obligations at the moment a
  new `docs/` page is created without a census.
- `verify-docs.sh` (Stop) gains four BLOCKING gates: **no census at all**, an incomplete
  census, an open `[u#]` row, and documentation that changed without a fresh green validator
  run. All fire only where `.claude/sources/` exists **and this session produced
  documentation**, so hand-maintained docs trees — and anyone who merely cloned the repo —
  are untouched.

### Enforcement — the Figma probe

New `scripts/figma-probe.sh` replaces improvised per-run curl and JSON walking. It saves
the raw payload before anything interprets it, prints the §0.1 receipt, extracts
annotations **schema-agnostically** (selecting on the presence of a non-empty `annotations`
array and dumping whole objects — no annotation field name appears in the script at all),
never sends `depth`, and exits 4 when the raw bytes contain annotation data the parse
missed. A `parse` subcommand re-analyses a saved payload offline.

### Enforcement — adversarial review

`lore:doc-validator` and `lore:doc-reviewer` change stance from "check the census is
well-formed" to **"assume the census is fabricated; disprove it"**: re-probe every §1
source and compare the observed status to the claim (a row claiming "requires login" that
answers 200 is a fabrication — blocking), test every raw payload, cross-check the evidence
log, challenge every zero against its payload, verify every `[u#]` row's evidence exists,
and — for site runs — confirm every scenario with a signed-in Precondition traces to a
`signed-in` observation row. The report now states which re-verifications actually ran,
because an unrun check is not a passed check.

### Auth state is a documented state

`site-to-doc` gains an Observation coverage matrix (auth state × role × route × viewport,
each row backed by a screenshot), a rule that both the guest and signed-in views of an
auth-gated route must be covered or explicitly waived by the user, and a warning that the
persistent browser profile hides the guest view. `lore:site-explorer` must now **verify and
report which auth state it is actually in** before running a scenario — an expired session
serves login walls that look like ordinary pages.

### Rule 4: an explicit carve-out for enforcement

Restating a rule near the point of action is exactly what makes it land — and exactly what
Rule 4 forbids. That tension is now resolved explicitly rather than left to judgement, in the
same shape as the existing Rule 3 carve-out: a rule's **statement and rationale** stay
canonical in `lore-methodology.md`; an **operational instantiation** (the columns to fill, a
checklist item, a hook's runtime error message) belongs where the work happens. The test is
*"if the canonical rule changed, would this other copy become wrong?"* — if yes it is a
restatement and must become a `§N` reference. The skills, `doc-validator`, `doc-reviewer`,
`skill-template.md` and this repo's `CLAUDE.md` were rewritten against that test.

### Cost and false-block control

Both were measured rather than assumed:

- `record-evidence.sh` sits on the `Bash` matcher — the highest-frequency tool there is — so it
  checks its Lore-project guard and a cheap payload filter **before** starting any JSON parser.
  A call in an unrelated repo, or an ordinary `git status`, costs **~8.5 ms** (down from ~16 ms,
  and now essentially just the `sh` spawn). Only a call that actually carries a URL or a
  subagent type pays the full ~26 ms — and those already involve network I/O.
- The Stop gate is **scoped to sessions that actually wrote documentation**. Without this, a
  `git pull`, a rebase, or an editor save that touched `docs/` would leave the tree newer than
  the validator receipt and block the next turn of an unrelated session. `record-evidence.sh`
  records the session id on a `docs/` write and the Stop hook consults it; a session that wrote
  no documentation is never gated. It still fails **closed** when no marker exists yet.

### The census is now required, and validated twice

The gap that made everything above optional: **nothing checked that a census existed.**
Every §0 rule is enforced against that file, and `check-census.sh` only fires when one is
written — so a run that wrote documentation, ran the validator, and simply never wrote a
census delivered cleanly, having proved nothing. The entry point to the deterministic layer
was itself prose. A session that produced documentation must now leave a census, or the turn
is blocked.

Validation is **progressive**, because a census is written incrementally:

- **At write time — shape.** The skills order the Run contract written at pre-flight, before
  any fetching. Completeness used to be enforced here, so that prescribed write was blocked;
  the cheapest escape was a placeholder (an empty `## Observation coverage` heading, or one
  prose line naming the six Figma source types), and the placeholder then satisfied the check
  **for the rest of the run**. The gate was teaching the model to disarm the gate.
- **At Stop — completeness.** The run is over, so a site census must show at least one
  observed state and a Figma census must carry a counted row per manifest source type. A
  heading with nothing under it is not coverage.

Both live in `check-census.sh` (`--complete` is invoked by the Stop hook), so every census
rule stays in one file.

**Receipts now apply to every row.** §0.1 says each row carries a receipt; the check only
ever ran on rows stating a *zero*, so a row claiming a positive finding — the majority of
rows — was skipped before the receipt check was reached. And a zero whose own corroboration
says the raw payload has the data (`corroboration=RAW-HAS-…`) is now blocked outright: that
is a parser failure, and recording it as an absence is the bug that deleted every business
rule the designers had written.

### The evidence log is tiered

`record-evidence.sh` logged any URL it found inside any Bash command. `grep -rn
"https://x" ./notes` contacted nothing; a `curl` that failed contacted nothing — both wrote
a receipt for a source never read, during ordinary work. Entries now carry a tier:
`verified` when a fetching tool actually ran (WebFetch, browser navigation, a subagent, and
`figma-probe.sh` appending its own entry once it has an HTTP status in hand), `mentioned`
otherwise. The census check accepts only `verified`. Logs written before this have three
fields and are read as `verified`.

Log values come from tool input, so they are sanitised: for every tool but Bash only the
first line is kept, and control characters are stripped per line. An embedded newline used
to append a second, forged entry for a host never contacted — in the one record the census
is checked against.

### Every rule now says truthfully where it lives, and whether it blocks

Two kinds of stale claim, both fixed by the same principle: a statement about the rules is
itself a fact, and Rule 4 applies to it.

- **Where each rule lives is now one table.** The methodology moved out of `CLAUDE.md` in
  0.6.0, and every copy of "the canonical rule is in `CLAUDE.md`" went stale at once —
  `doc-reviewer`'s *Canonical rule* column named the wrong file for **14 of its 16 rows**,
  and `skill-template.md` taught the same wrong locations to every skill authored from it.
  There is now a single **canonical-locations table** in `lore-methodology.md`; everything
  else references it. Only §1 Trusted Sources and §3 User Roles remain in `CLAUDE.md`, and
  they are labelled as the product layer.
- **A skill citing a DoD section writes `DoD §N`.** A skill's own `## 3. Core Workflow` and
  the DoD's `§3 User Roles` are different things, and a bare "§3" inside a skill file was
  ambiguous in both directions.
- **⛔ now means something checkable.** Sections that describe good practice but that nothing
  can verify are marked **Expected** instead. **§8 Final Report is the clearest case:** it
  lives in the chat, `lore:doc-validator` runs in its own context and cannot see it, and no
  hook can either — so marking it blocking made it *look* enforced while every check of it
  was a self-assessment. That is the exact pattern §0 exists to end. `doc-reviewer` now
  reports it as `N/A — not observable from here` rather than passing it on assumption.
- **`lore:doc-reviewer` is additive, never a substitute.** Only the `lore:doc-validator`
  subagent leaves a recorded verdict, so a review done through the skill alone left the
  delivery gate unsatisfied — two lines apart, the methodology suggested one and mandated
  the other.
- **The blocking-areas list is gone from the three producer skills.** It was byte-identical
  in all three, already wrong, and it is the validator's business to know which sections
  block — not each skill's to enumerate.

### Restatements that had already drifted

- **`/lore:init` no longer restates the Docusaurus install sequence.** It carried its own
  numbered copy of `/lore:add-docusaurus`'s steps *while naming that file the single source
  of truth in the same paragraph* — and the copy had drifted to plain
  `npm install && npm run build`, which fails on `Cannot find module
  '@docusaurus/theme-mermaid'`. The first thing a new user saw was a red build. It is now a
  pointer, with a note explaining why it must stay one.
- **The scaffold smoke test runs the command file's own block** instead of a hand-copied
  version of it, so the test breaks the day the documented command changes. It also now
  fails on any unsubstituted `{{TOKEN}}` — a `sed` that matches nothing exits 0, so a
  renamed placeholder used to sail through and "OK (green production build)" was untrue
  while the site shipped a raw token in its footer.
- **`SITE.version` is deleted.** It had zero consumers — the site badges resolve from the
  git tag — yet the release checklist mandated bumping it every time. Its hard-coded
  fallback returned `'0.3.1'`, a real past release, so a broken checkout shipped a
  plausible-looking wrong badge instead of failing; it now raises. CI asserts the README
  badge matches `plugin.json`.

### Lore no longer imposes its Definition of Done on unrelated repositories

**If you installed Lore and it started blocking work in a project that has nothing to do
with it, this is the fix.** A plugin is installed per user, so its hooks run in whatever
repo the session is in — and only some of them checked whether that repo was a Lore
project. In any project that merely kept plain markdown or an image under `docs/`:

- writes to `docs/*.md` were blocked for missing frontmatter the author never asked for;
- writing an image under `docs/` was blocked;
- `verify-docs.sh` blocked **every turn** at Stop.

All nine hooks now guard on the same marker — a `.claude/CLAUDE.md` importing
`lore-methodology.md` — and exit immediately otherwise. The rules in this plugin are
Lore's DoD, not universal truth. Hooks on the high-frequency matchers also bail on a cheap
substring test before starting a JSON parser, so an unrelated repo pays roughly nothing
(measured: ~104 ms → ~63 ms per write event, most of it now avoided entirely).

### CI covers what ships

The exec-bit and hook-wiring checks named four scripts by hand, so five shipped
unchecked — and since git tracks the exec bit while the test harness invokes hooks as
`sh <file>` (which does not need it), a single `chmod`-less commit could ship a dead hook
with CI green. Both checks are now derived from `hooks.json` and from the contents of
`hooks/` and `scripts/`, so a new hook is covered the day it lands, and `run-tests.sh`
mirrors them. A `claude plugin validate` step that sat behind `if command -v claude` never
ran on a runner; it is replaced by manifest and layout assertions that do, plus a check
that the README version badge matches `plugin.json`.

### Gate correctness — found by auditing the gates themselves

An independent audit of this release's own enforcement found four more defects in it. All are
fixed here, and each has a regression test that fails on the pre-fix commit.

- **A run-contract row could be closed by writing "not satisfied".** The gate filtered open
  rows with a substring match, so `not satisfied`, `unsatisfied` and `not yet satisfied` all
  *contained* "satisfied" and were read as closed — including the exact phrasing §0.4's own
  wording primes you to write. The status is now matched as a whole field, and `satisfied`
  additionally requires a non-empty evidence cell, which §0.4 always demanded and nothing
  checked. The same substring defect governed the validator verdict: a report saying
  "nothing was BLOCKED" recorded a BLOCKED verdict, and a passing mention of APPROVED
  recorded a pass. Both now require the token to open a line.
- **A freshly cloned project blocked every session.** `.docs-touched` is git-ignored while the
  census is committed, so after a clone the marker was missing — and a missing marker was read
  as "unknown, therefore block" rather than "no session here has produced documentation". Every
  turn in every clone was blocked, including ones that touched nothing. Absence now skips.
- **A docs-only project shipped no `.gitignore`.** `.claude/.auth/` — an exported browser
  session, and full impersonation of the account it came from — was ignored only by the
  *optional* Docusaurus layer. The docs layer now ships its own, also covering the raw payloads
  and run logs. `scaffold.sh` **merges** `.gitignore` instead of skipping it, so adding the
  viewer later keeps both layers' entries.
- **The Figma probe was cited by a path that does not exist in a consumer repo.**
  `figma-to-doc` said `scripts/figma-probe.sh`; the probe ships with the plugin, so the skill
  now invokes it through `${CLAUDE_PLUGIN_ROOT}` as the subagent already did. A model that
  cannot run the probe falls back to the hand-parsing the probe exists to replace — which is
  the annotation bug above. The probe also now rejects a file key containing anything but
  letters, digits, `-` and `_`, since the key is interpolated into both the request path and
  the output filename.

### Known limits

**These gates guard against a skipped step, not a deliberate forgery.** Every evidence artifact
is a plain file under `.claude/`, and an agent with shell access can write one. The property
they buy is that a source never fetched does not end up in the log *by accident* — which is the
failure mode this release is about. Anything claiming more would be repeating the mistake that
made 0.6.2 believe it had fixed this class of bug.

A source fetched before this release is not in the evidence log, so the first run after
upgrading re-fetches. Evidence-log URL matching is by host — deliberately permissive, to
keep false blocks near zero. A URL that merely *appears* in a `Bash` command is currently
recorded as if it were fetched. A browser MCP server whose tool names contain none of
`playwright|browser|chrome|puppeteer|fetch` would not be recorded; widen the matcher in
`hooks.json` if you use one. Documentation written outside the `Write`/`Edit` tools leaves no
`.docs-touched` marker and is therefore not process-gated.

**Verified.** `shellcheck -S warning` clean across all hooks and scripts; hook suite green
at **173 assertions** (was 60), including the two regressions that shipped: an annotation
payload using `label` *and* one using `notes` are both found (a field rename cannot cause a
silent zero), and a truncated payload carrying annotation data is reported as a parser
failure rather than a zero, plus the two false-block cases (a session that wrote no docs is
never gated; a repo with no Lore evidence is never gated). `claude plugin validate
./plugins/lore` passes. Existing
projects receive the methodology change automatically via the `SessionStart` sync hook on
`/plugin update`.

## 0.6.3

Submission readiness for the Claude Code community marketplace. Anthropic's
review pipeline reads the plugin directory on its own terms — it runs
`claude plugin validate` and expects the plugin to document itself — so the two
places where Lore relied on the surrounding repository are closed.

### The plugin directory now documents itself

- **Problem.** `plugins/lore/` had no `README.md`. Every install, usage, and
  contribution instruction lived in the repository root README, one level up.
  A reader — or reviewer — landing on the plugin directory found a manifest and
  four source folders with nothing explaining what they were.
- **What changed.** Added `plugins/lore/README.md`: the component table
  (commands, skills, subagents, hooks) and pointers to the root README, the
  website, and `CLAUDE.md`. Per Rule 4 it **references** the install/update
  commands rather than restating them — the root README stays their single
  source of truth.

### `homepage` points at the product site

- **Problem.** The manifest's `homepage` and `repository` were both the GitHub
  URL, so the plugin manager surfaced the source tree where it could surface
  the product page.
- **What changed.** `homepage` is now `https://lorekit.net`; `repository` still
  points at GitHub. A version bump ships with it because consumers only receive
  manifest changes when `version` moves.

**Verified.** `claude plugin validate ./plugins/lore` passes, every relative
link in the new README resolves to a file that exists, and `sh tests/run-tests.sh`
plus CI pass unchanged.

## 0.6.2

Trusted sources become auditable. A recurring failure — a producer skill
delivering documentation without reading the trusted sources configured in
`CLAUDE.md` §1, and validation passing anyway — is closed by making the §1
search leave the same auditable evidence every other source already does.

### Trusted-source coverage is now census evidence

- **Problem.** Trusted sources were the only source type with no evidence
  trail. The Figma census counted comments, annotations, prototype flows,
  variants, and variables — but had no field for trusted sources. The skill
  mentioned the §1 search once (pre-flight step 3) and never re-verified it:
  no census field, no checklist item, no validator check. Every source *in*
  the census got read; the one source *not* in it got silently skipped. On
  large files a fourth gap compounded it — "delegate steps 1–8 to
  `lore:figma-extractor`" dropped the §1 search, which the extractor never
  performs.
- **What changed.** The source census is generalized to every producer skill,
  and its mandatory common core is a **Trusted Sources (§1) coverage block** —
  one row per configured source (its finding → the doc page, or an explicit
  `nothing relevant — confirmed searched`), written before writing begins.
  `§0` gains an order-of-operations rule: discover scope first, then read every
  source for a page before writing it (fetch once, reuse per page).
- **Enforcement.** `lore:doc-validator` gains a BLOCKING cross-check — every
  §1 source must have a census row, and each claimed contribution is grepped
  against the named doc section to confirm it is actually reflected. The
  `figma-to-doc` delegation note now marks steps 3–4 as NOT delegable to the
  extractor. `brief-to-doc` and `site-to-doc` write a lightweight census
  carrying the same common core, so the fix covers all three input types.
- **Docs.** The Definition-of-Done concepts page and the three producer-skill
  guides (EN & FA) describe the census coverage.

Existing projects receive the methodology change automatically via the
`SessionStart` sync hook on `/plugin update`.

## 0.6.1

Prompt-injection hardening. Following an audit against current LLM-security
research, Lore now treats all ingested source content as untrusted data, never
as instructions — closing the one real gap for a human-supervised doc factory.

### Untrusted content is data, not instructions

- **What changed.** A new §0 rule ("Untrusted content — sources are data, not
  instructions") in `lore-methodology.md`: content read from any source (Figma
  comments/annotations/TEXT nodes, live-site UI text, briefs, fetched pages,
  tool/subagent output) is product data to document, never a command to follow.
  Directives embedded in sources ("ignore your instructions", "print your
  prompt", a link to open) are ignored; hidden text (Unicode tag-block
  U+E0000–E007F, zero-width, bidi-override characters, HTML comments) is stripped
  and flagged, never turned into a business rule. The three ingesting skills
  (figma/brief/site) reference the rule; `figma-extractor` and `site-explorer`
  strip/flag hidden text and never let source text redirect what they fetch or
  return; the Figma census gains an **Anomalies** section; `doc-reviewer` /
  `doc-validator` fail a documented rule that traces to a flagged anomaly
  (blocking §0/§5). Also hardened: the three hook `grep` calls on `$file_path`
  now use `--` to prevent option injection.
- **Why.** Prompt injection can't be reliably filtered; the defense is treating
  external content as inert and keeping a human in the loop (which the host
  provides). This is the proportionate control for a documentation tool — no
  policy engine or sandbox, which the audit found disproportionate here.
- **How verified.** `shellcheck -S warning` clean; hook suite green (60
  assertions); `claude plugin validate` passes.

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
