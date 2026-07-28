---
name: <skill-name>
description: <When to use this skill — trigger keywords and the input type it handles.>
user-invocable: true
---

# <Skill Title>

**This skill provides input-specific instructions for documenting from <input source>. It complements (does not override) the global system prompt in `.claude/CLAUDE.md`.**

> **GOLDEN RULE (an instance of Rule 4 — Single Place of Truth):**
> This skill contains ONLY input-specific content. Do NOT restate any global rule
> (DoD, image paths, user roles, trusted sources, final-report structure).
> Reference the relevant Section instead of copying it.
>
> **Where each rule lives is itself a single fact:** the canonical-locations table in
> `.claude/lore-methodology.md`. Read it there rather than reproducing it here — a copy
> of that map is exactly what went stale everywhere when the methodology moved out of
> `CLAUDE.md`.
>
> When citing a DoD section from inside this skill's own numbered headings, write
> **`DoD §N`**. This skill's `## 3.` and the DoD's `§3` are different things.

---

## 1. When to Use

- Trigger keywords / situations that should invoke this skill.
- The scope this skill covers (and what it does NOT cover).

---

## 2. Pre-Flight Checklist (BLOCKING)

Input-specific source gathering that must be completed before writing.
Reference `CLAUDE.md` Section 0 (Exhaust Every Source) and Section 1 (Trusted Sources) for the
global requirement — list here ONLY the steps unique to this input type.

### Sources you must read (per §0)

This skill's **source manifest** — the concrete list §0 requires you to exhaust for this
input type. List every source this input carries that could describe how the product works,
plus the configured trusted sources in §1. Reading a subset is a blocking failure; state
every zero-case explicitly. New must-read sources for this input type are added here.

| # | Step | How to Verify |
|---|------|---------------|
| 0 | **Write the Run contract** (before anything else) | Every explicit user instruction for this run is a `[u#]` row in the census with a status and evidence slot (per §0.4) |
| 1 | ... | ... |

> **Step 0 is not optional and not input-specific — every skill starts with it** (§0.4). Name here
> only what an instruction typically looks like *for this input type*.
>
> Include a step to **search every configured trusted source in §1** for material about the pages
> in scope. Each row is receipted per §0.1–§0.3 — the census skeleton in §3 defines the columns;
> do not restate the rules here. Per Rule 3, also check `.claude/lesson-learned.md` before starting.

---

## 3. Core Workflow

The unique value of this skill — the only detailed part.
Everything here must be input-specific (e.g., API calls, capture steps, extraction logic)
that is NOT already covered by a global rule in CLAUDE.md.

---

## 4. DoD Additions (input-specific deltas only)

Only the deltas this input type adds to the global DoD.
For the base rules, reference: scenarios → `CLAUDE.md` §4; image paths / technical
validity → `CLAUDE.md` §6 + Rule 1. Do NOT restate those rules here.

---

## 5. Final Report Additions (skill-specific fields only)

The base final-report structure lives in `CLAUDE.md` §8 — do NOT restate it.
List here ONLY the extra fields this skill must add to the report
(e.g., Figma file + frames, URLs tested, questions asked/answered).

---

## 6. Completion Checklist

- [ ] Input-specific pre-flight steps completed
- [ ] Only input-specific content in this skill (no restated global rules)
- [ ] Source census written, with a receipted row per source (DoD §0/§0.1)
- [ ] Every `[u#]` run-contract row satisfied with evidence, or waived (DoD §0.4)
- [ ] All BLOCKING rules from the global DoD satisfied
- [ ] **`lore:doc-validator` run and green** — this is the last step of every producer
      skill, and a `Stop` hook blocks delivery without it. A skill authored from this
      template that omits the line omits the step the hook blocks on.

---

## 7. Reference Example

See [examples/<example-file>.md](examples/<example-file>.md) for a complete example.
