---
description: Release a new Lore version end to end — interactive and gated (ask version → bump all strings → PR → tag → GitHub Release → post-tag redeploy + verify live badge)
argument-hint: "[version e.g. 0.3.4 — optional; I'll ask if omitted]"
---

# /release — Lore maintainer release runbook

Drive a full Lore release for **this repo** (maintainer tool — not shipped inside `plugins/lore/`).

The canonical step list and the exact version-string locations live in the **Versioning** section of [`CLAUDE.md`](../../CLAUDE.md) (Rule 4 — single place of truth). Follow it. This command does **not** restate those rules; it adds the parts that aren't in the checklist: the interactive **version gate**, the PR flow, and the post-tag verification.

## 0. Preconditions
- `git status` — confirm the tree is clean, or that the pending changes ARE the release content.
- Review what changed since the last tag: `git log $(git describe --tags --abbrev=0)..HEAD --oneline` plus the diff. Summarize what is user-facing vs internal-only.

## 1. Ask the version — GATE, never skip
- Propose a semver bump from the changes: **patch** for fixes, **minor** for backward-compatible features, **major** for anything that breaks an existing project (a removed/renamed command, an incompatible template layout, or a rule that changes what a project must do to deliver).
- If `$ARGUMENTS` already names a version, confirm it back to the user; otherwise **ASK** which version.
- ⛔ Do not bump, branch, push, or tag before the user answers.

## 2. Bump every version string together
Per CLAUDE.md §Versioning, bump BOTH of these so they match (don't bump only `plugin.json`) — CI asserts they agree, so a half-bumped release fails the PR:
- `plugins/lore/.claude-plugin/plugin.json` → `version`
- `README.md` → the `img.shields.io/badge/version-X.Y.Z` badge URL (hardcoded — does not auto-track the manifest)

⛔ **There is no third string.** `website/landing/src/config.ts` used to carry `SITE.version`; it had zero consumers, so bumping it was pure ceremony and its stale fallback could ship a wrong badge. It was deleted in 0.7.0 — do not reintroduce it (CLAUDE.md §Versioning).

The **site header badges** (lorekit.net / docs.lorekit.net) resolve from the git tag at build time — no manual edit, but they only update on a post-tag redeploy (step 6).

## 3. Sync content the release actually changed
- If the change affects the **website** (landing or docs — both EN & FA) or the **README** beyond the version number, update that content too.
- Skip if the change is internal-only (e.g. a template/CSS fix with no reader-facing doc). State which you chose and why.

## 4. CHANGELOG
- Add a new `## X.Y.Z` section to `CHANGELOG.md`: problem → fix → how it was verified. Match the existing entry style.

## 5. Land via PR — not a direct push
`main` has required checks; direct push bypasses CI.
- Branch `release-X.Y.Z`, commit, push, open a PR to `main`.
- Wait for all checks: `gh pr checks <n> --watch`. Then squash-merge, delete the branch, and `git checkout main && git pull --ff-only`.

## 6. Tag + Release + redeploy
- Annotated tag: `git tag -a vX.Y.Z -m "vX.Y.Z — <summary>"` then `git push origin vX.Y.Z`.
- Publish the GitHub Release from this version's CHANGELOG section:
  `gh release create vX.Y.Z --title "Lore vX.Y.Z" --notes-file <section-file> --latest`.
- The deploy workflows fire on the `main` merge, which happened **before** the tag existed — so they built the badge from the *previous* tag. Re-run them now that the tag exists:
  `gh workflow run deploy-landing.yml --ref main` and `gh workflow run deploy-docs.yml --ref main`. Wait for both to succeed.

## 7. Verify and report
- Confirm the live header badge reads X.Y.Z:
  `curl -s https://lorekit.net/ | grep -o 'brand-version[^>]*>v[0-9.]*'` and `curl -s https://docs.lorekit.net/ | grep -o 'v[0-9][0-9.]*'`.
- Report back: the PR link, the Release link, and the verified live badge value.
