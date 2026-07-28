// Site-wide constants shared across both locales.

// NOTE: there is deliberately no `version` here. It had zero consumers — the header
// badges resolve the version from the git tag at build time — yet the release
// checklist mandated bumping it, so every release hand-edited a dead constant and
// two stale fallbacks sat behind it. The version lives in plugins/lore/.claude-plugin/
// plugin.json; CI asserts the README badge matches it.
export const SITE = {
  name: 'Lore',
  domain: 'lorekit.net',
  docsUrl: 'https://docs.lorekit.net',
  githubUrl: 'https://github.com/hamidpl/lore',
  changelogUrl: 'https://github.com/hamidpl/lore/blob/main/CHANGELOG.md',
  licenseUrl: 'https://github.com/hamidpl/lore/blob/main/LICENSE',
  marketplaceRepo: 'hamidpl/lore',
} as const;

// Verbatim commands, run inside Claude Code. Language-agnostic.
export const INSTALL_COMMANDS = [
  '/plugin marketplace add hamidpl/lore',
  '/plugin install lore@lore-marketplace',
] as const;

export const INIT_COMMAND = '/lore:init';

export const PLAYWRIGHT_COMMAND =
  'claude mcp add playwright -- npx @playwright/mcp@latest';
