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
> Reference the relevant Section in `.claude/CLAUDE.md` instead of copying it.
>
> Canonical locations:
> - Global rules / DoD / image paths / roles / sources → `.claude/CLAUDE.md`
> - Lessons learned → `.claude/lesson-learned.md`
> - Document template → `export-sample-data/Product Document Template.md`

---

## 1. When to Use

- Trigger keywords / situations that should invoke this skill.
- The scope this skill covers (and what it does NOT cover).

---

## 2. Pre-Flight Checklist (BLOCKING)

Input-specific source gathering that must be completed before writing.
Reference `CLAUDE.md` Section 0 (Pre-Writing) and Section 1 (Trusted Sources) for the
global requirements — list here ONLY the steps unique to this input type.

| # | Step | How to Verify |
|---|------|---------------|
| 1 | ... | ... |

> Per Rule 3, also check `.claude/lesson-learned.md` for relevant entries before starting.

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
- [ ] All BLOCKING rules from the global DoD satisfied (see `CLAUDE.md`)

---

## 7. Reference Example

See [examples/<example-file>.md](examples/<example-file>.md) for a complete example.
