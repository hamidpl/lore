import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js — don't use client-side code here (browser APIs, JSX...).

// Resolved at build time from the latest git tag (e.g. v1.0.0). When git or its
// tags are unavailable (a shallow CI clone, a tarball), fall back to the plugin
// manifest rather than a hardcoded string -- per Rule 4 the version has exactly
// two canonical homes, and a third copy here would silently go stale.
function getVersion(): string {
  try {
    const tag = execSync('git describe --tags --abbrev=0', {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (tag) return tag.replace(/^v/, '');
  } catch {
    /* no git / no tags */
  }
  return JSON.parse(
    readFileSync('../../plugins/lore/.claude-plugin/plugin.json', 'utf8'),
  ).version;
}

const VERSION = getVersion();
const GITHUB_URL = 'https://github.com/hamidpl/lore';
const CHANGELOG_URL = `${GITHUB_URL}/blob/main/CHANGELOG.md`;
const SITE_URL = 'https://lorekit.net';

const config: Config = {
  title: 'Lore',
  tagline: 'A product-documentation factory for Claude Code',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://docs.lorekit.net',
  baseUrl: '/',

  organizationName: 'hamidpl',
  projectName: 'lore',

  onBrokenLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'fa'],
    localeConfigs: {
      en: { label: 'English', direction: 'ltr', htmlLang: 'en' },
      fa: { label: 'فارسی', direction: 'rtl', htmlLang: 'fa-IR' },
    },
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: '/',
          editUrl: `${GITHUB_URL}/tree/main/website/docs/`,
        },
        blog: false,
        theme: {
          // custom-rtl.css only affects html[dir='rtl'] (the fa locale).
          customCss: ['./src/css/custom.css', './src/css/custom-rtl.css'],
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Lore',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docs',
          position: 'left',
          label: 'Documentation',
        },
        { type: 'localeDropdown', position: 'right' },
        { href: CHANGELOG_URL, label: `v${VERSION}`, position: 'right' },
        { href: GITHUB_URL, label: 'GitHub', position: 'right' },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            { label: 'Introduction', to: '/' },
            { label: 'Getting started', to: '/getting-started/install' },
            { label: 'Guides', to: '/guides/from-figma' },
            { label: 'Reference', to: '/reference/commands' },
          ],
        },
        {
          title: 'Project',
          items: [
            { label: 'Lorekit.net', href: SITE_URL },
            { label: 'GitHub', href: GITHUB_URL },
            { label: 'Changelog', href: CHANGELOG_URL },
            { label: 'License (MIT)', href: `${GITHUB_URL}/blob/main/LICENSE` },
          ],
        },
      ],
      copyright: `Copyright © 2026 Lore. Released under the MIT License.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'json'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
