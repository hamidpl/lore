// Site-wide constants shared across both locales.

export const SITE = {
  name: 'Lore',
  version: '0.3.2',
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
