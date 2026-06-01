# Lessons Learned

This is a **living knowledge base** (per Rule 3 in `CLAUDE.md`), not a log file. Before proposing a solution to any error, search this file first; if a relevant entry exists, apply it immediately. If you hit a new issue, after resolving it append an entry using the format below.

**Entry format:**

```markdown
### [Issue Title]

**Problem:** [what went wrong — specific, observable]
**Root Cause:** [underlying reason]
**Solution:** [concrete steps applied]
**Preventive Rule or Pattern:** [actionable guideline to avoid recurrence]
**Date:** YYYY-MM-DD
```

> This template ships with a couple of high-frequency general lessons already seeded. Product-specific lessons accumulate here over time. Many general lessons are also encoded proactively in the Lore plugin skills.

---

### Docusaurus Image Path Resolution

**Problem:** Images referenced as `/static/img/...` in markdown fail to render and break the production build.

**Root Cause:** Docusaurus serves the `static/` folder at the site root, so a file at `static/img/x.png` is served at `/img/x.png`. The `/static/` prefix points at a path that does not exist in the build output.

**Solution:** Store images under `static/img/{section}/` but reference them in markdown as `/img/{section}/...` (no `static/`).

**Preventive Rule or Pattern:** Physical storage = `static/img/`; markdown reference = `/img/`. Enforced by the Lore plugin's `check-image-path.sh` hook (blocks `/static/img/` in `docs/`). See `CLAUDE.md` §6 / Rule 1.

**Date:** 2026-05-31

---

### Figma Section vs Individual Frame Export

**Problem:** Exporting a Figma SECTION node produces a single composite image with all child frames side-by-side, unusable for inline documentation.

**Root Cause:** Sections are containers holding multiple frames; the export API renders the whole container as one image.

**Solution:** Export individual FRAME nodes only. Discover child frames with `GET /v1/files/{key}/nodes?ids={section_id}&depth=1`, then export each frame at `scale=2`.

**Preventive Rule or Pattern:** Never export SECTION nodes — always individual FRAMEs. Batch ~5 at a time to avoid render timeouts. Encoded in the `lore:figma-to-doc` skill.

**Date:** 2026-05-31
