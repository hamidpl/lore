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
    // Example of a content section — uncomment and adapt once you add docs/{section}/.
    // A multi-page section (split per the CLAUDE.md §2 split rule) lists the overview
    // `index` first, then the sibling sub-pages. See website/docs/sidebars.ts for a
    // real working multi-page category.
    // {
    //   type: 'category',
    //   label: '{{SECTION_LABEL}}',
    //   collapsed: false,
    //   items: [
    //     '{{section}}/index',       // overview / hub page
    //     '{{section}}/{{sub-topic}}', // sibling sub-page (when the section is split)
    //   ],
    // },
  ],
};

export default sidebars;
