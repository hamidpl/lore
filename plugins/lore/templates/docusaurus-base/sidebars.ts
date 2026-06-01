import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// ---------------------------------------------------------------------------
// SETUP: this sidebar must mirror your docs/ folder structure.
// Start minimal (just the intro page); add a category per docs/{section}/ as
// you create content. See SETUP.md for the new-product procedure.
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
