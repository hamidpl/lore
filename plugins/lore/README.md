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

Lore has no telemetry and no server of its own.

**Hooks.** Every hook is a local POSIX shell script that reads the hook payload and files in
your project; none makes a network request. Outside a Lore docs project every hook exits
immediately — see [scope and safety](https://docs.lorekit.net/concepts/enforcement-hooks#scope-and-safety).

**Network.** Requests happen during the skills and commands you run:

- **`lore:figma-to-doc`** reads Figma through your Figma MCP server or the Figma REST API
  (`api.figma.com`), authenticated by the `FIGMA_TOKEN` environment variable. Lore's script
  sends the token only to Figma and never echoes it or writes it to a file. Set it with
  `export` in your shell, not in the chat.
- **`lore:site-to-doc`** drives a browser through your Playwright MCP server on the site you
  name — which, like any browser, also loads whatever that site loads.
- **Trusted sources** listed in your project are fetched with Claude Code's own tools, under
  its permission prompts.
- **`lore:doc-validator`** runs before every delivery and re-checks the HTTP status of the
  sources a run claims to have read. It requests status and headers only and saves nothing.
- **`/lore:add-docusaurus`** downloads Docusaurus from the npm registry.

What a skill fetches is set by its instructions to the model, not enforced by code: a skill
is told which sources to read, not prevented from reading others.

**Files.**

- `/lore:init` scaffolds the docs project and never overwrites an existing file — see
  [template layers](https://docs.lorekit.net/reference/template-layers). Its
  `.claude/settings.json` registers this marketplace and enables the plugin, so
  collaborators on the repository get the same rules.
- `.claude/lore-methodology.md` belongs to Lore: a session-start hook keeps it identical to
  the installed plugin's copy.
- Raw payloads and the hooks' bookkeeping live under `.claude/sources/` and are git-ignored;
  the source census beside them is committed as the record of what each run read. Exported
  browser login state goes to `.claude/.auth/`, also git-ignored. What each hook writes and
  why: [`hooks/ARCHITECTURE.md`](hooks/ARCHITECTURE.md).
- Captured screenshots are recompressed in place when a PNG optimizer is installed; nothing
  changes when none is.

**Permissions.** No Lore file grants a permission. `lore:site-to-doc` is instructed to ask
before adding `mcp__playwright` to `permissions.allow` in `.claude/settings.json`, so a
browser run isn't interrupted at every step; remove it any time with `/permissions`.

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
