# Lore — Product Documentation Factory

**Turn designs, briefs, and living products into documentation that lasts.**

[![License](https://img.shields.io/badge/license-MIT-green.svg)](../../LICENSE)
[![Website](https://img.shields.io/badge/website-lorekit.net-ff7a59.svg)](https://lorekit.net)

**Lore** is a [Claude Code plugin](https://code.claude.com/docs/en/plugins) that packages a reusable, product-agnostic **documentation factory**. Install it in any documentation repo to get the same skills, review subagents, and BLOCKING-rule enforcement hooks — maintained once, consumed everywhere.

This directory is the plugin itself. The repository that contains it is also its marketplace.

## What's inside

| Component | Name | Purpose |
|-----------|------|---------|
| Command | `/lore:init` | Scaffold a new docs project (3-question wizard; optional Docusaurus) |
| Command | `/lore:config` | Fill in / edit settings anytime (site URL, sources, template, brand, language) |
| Command | `/lore:add-docusaurus` | Add the Docusaurus viewer to a docs-only project later |
| Skill | `lore:figma-to-doc` | Generate docs from Figma design files |
| Skill | `lore:brief-to-doc` | Generate docs from briefs / PRDs / user stories |
| Skill | `lore:site-to-doc` | Document live product behavior (scenario runner + screenshots) |
| Skill | `lore:doc-reviewer` | Validate docs against the Definition of Done |
| Subagent | `lore:doc-validator` | Read-only DoD validator (run by producer skills before delivery) |
| Subagent | `lore:figma-extractor` | Heavy Figma extraction worker (keeps main context clean) |
| Subagent | `lore:site-explorer` | Heavy live-site exploration worker — drives the browser, captures screenshots |
| Subagent | `lore:doc-reviser` | Narrow-contract fixer — applies the validator's findings as one batch, only at the targets they name, with no ability to fetch |
| Hooks | `hooks/hooks.json` | BLOCKING enforcement of image paths, frontmatter, and tooling references — plus the evidence gates (a hook-written fetch log, receipted source censuses, a mandatory validator run, citation protection) that leave a skipped source visible at delivery |

## What Lore runs, sends, and writes

Lore has no telemetry and no server of its own: nothing it does reports back to its author.

**Hooks run locally and never touch the network.** Every hook in `hooks/hooks.json` is a
POSIX shell script that reads the hook payload (via `jq` or `python3`) and files in your
project. Each one exits immediately unless the project is a Lore docs project — one whose
`.claude/CLAUDE.md` imports `@lore-methodology.md` — so in any other repository they do nothing.

**Network requests happen only for work you ask for:**

- **`lore:figma-to-doc`** reads the Figma file through the Figma MCP server you configured, or
  through `scripts/figma-probe.sh`, which calls the Figma REST API (`https://api.figma.com`)
  with the personal access token you provide in `FIGMA_TOKEN`. The token is sent only to Figma
  and is never printed or written to disk. Responses are saved under `.claude/sources/raw/`,
  which the scaffolded `.gitignore` excludes.
- **`lore:site-to-doc`** drives a browser through the Playwright MCP server you install, and
  visits only the site you name. Screenshots are saved to `static/img/`. Login state lives in
  Playwright's own browser profile; if you choose to export it, it goes to `.claude/.auth/`,
  which the scaffolded `.gitignore` excludes.
- **Trusted sources** you list in your project are fetched with Claude Code's own tools
  (such as WebFetch), with Claude Code's usual permission prompts.
- **`/lore:add-docusaurus`** downloads the latest Docusaurus from the npm registry
  (`npx create-docusaurus@latest`, then `npm install`) — only when you run that command.

**Files written in your project:**

- `/lore:init` scaffolds the docs project (`.claude/`, `docs/`, `templates/`, `README.md`,
  `.gitignore`). It never overwrites an existing file; `.gitignore` is merged by appending
  missing lines only. The scaffolded `.claude/settings.json` registers this marketplace and
  enables the plugin, so collaborators on the repository get the same rules.
- On session start, a hook keeps `.claude/lore-methodology.md` identical to the installed
  plugin's copy. Lore owns that file; you don't edit it.
- Hooks keep local bookkeeping under `.claude/sources/` — which sources were actually
  fetched (`.evidence-log`) and which validator verdict covers the current content
  (`.validator-receipt`, `.validator-history`). They are plain text files in your repository.
- `scripts/optimize-images.sh` recompresses captured PNGs in place with `pngquant`, `oxipng`
  or `optipng` when one is installed, and changes nothing when none is.

**Permissions.** Lore never changes Claude Code's permission settings on its own.
`lore:site-to-doc` *offers* to add `mcp__playwright` to `permissions.allow` in your project's
`.claude/settings.json` so a browser run is not interrupted by a prompt at every step; it does
so only if you agree, and you can remove it any time with `/permissions`.

## Install and usage

Install, enable, update, and pin instructions — plus the quick start and the full
walkthrough — live in the [repository README](../../README.md).

Guides and the skill reference are on the website: [lorekit.net](https://lorekit.net) ·
[docs.lorekit.net](https://docs.lorekit.net) (EN & FA).

## Contributing

Architecture, authoring rules, and the release checklist live in
[`CLAUDE.md`](../../CLAUDE.md). New or updated skills must follow the canonical
structure in [`templates/skill-template.md`](templates/skill-template.md).

Run the test suite before any change lands:

```bash
sh tests/run-tests.sh          # from the repository root
claude plugin validate ./plugins/lore
```

## License

[MIT](../../LICENSE). The bundled Vazirmatn font is licensed separately under the
SIL Open Font License 1.1 (see
[`templates/rtl-assets/static/fonts/LICENSE-Vazirmatn`](templates/rtl-assets/static/fonts/LICENSE-Vazirmatn)).
