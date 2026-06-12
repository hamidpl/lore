import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// ---------------------------------------------------------------------------
// SETUP: this sidebar must mirror your docs/ folder structure.
// Start minimal (just the intro page); add a category per docs/{section}/ as
// you create content. Mirror the Documentation Structure section in
// .claude/CLAUDE.md (the single source of truth for the section hierarchy).
// ---------------------------------------------------------------------------

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    // Example of a content section — uncomment and adapt once you add docs/{section}/:
    // {
    //   type: 'category',
    //   label: '{{SECTION_LABEL}}',
    //   collapsed: false,
    //   items: [
    //     '{{section}}/index',
    //   ],
    // },
  ],
};

export default sidebars;
