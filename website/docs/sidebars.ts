import type { SidebarsConfig } from '@docusaurus/plugin-content-docs';

// This runs in Node.js — don't use client-side code here (browser APIs, JSX...).

const sidebars: SidebarsConfig = {
  docs: [
    'intro',
    {
      type: 'category',
      label: 'Getting started',
      collapsed: false,
      items: [
        'getting-started/install',
        'getting-started/quick-start',
        'getting-started/configure',
      ],
    },
    {
      type: 'category',
      label: 'Authoring guides',
      collapsed: false,
      items: [
        'guides/from-figma',
        'guides/from-a-brief',
        'guides/from-a-live-site',
        'guides/review-and-validate',
        'guides/add-docusaurus',
      ],
    },
    {
      type: 'category',
      label: 'Concepts',
      collapsed: false,
      items: [
        'concepts/division-of-responsibility',
        'concepts/definition-of-done',
        'concepts/enforcement-hooks',
        'concepts/multilingual-rtl',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      collapsed: false,
      items: [
        'reference/commands',
        'reference/skills-and-subagents',
        'reference/template-layers',
      ],
    },
    'versioning',
  ],
};

export default sidebars;
