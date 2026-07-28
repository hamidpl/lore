/* ---------------------------------------------------------------------------
   Landing copy (English only — the landing is single-language; the docs
   subdomain is the multilingual surface). All claims are drawn from the repo's
   README / CHANGELOG / plugin.json — nothing invented.
   --------------------------------------------------------------------------- */

export const t = {
  meta: {
    title: 'Lore — Product Documentation Factory for Claude Code',
    description:
      'A reusable, product-agnostic documentation factory packaged as a Claude Code plugin. Turn Figma designs, briefs, or a live product into maintainable docs.',
  },
  nav: {
    docs: 'Docs',
    github: 'GitHub',
    changelog: 'Changelog',
    getStarted: 'Get started',
    toggleTheme: 'Toggle theme',
  },
  hero: {
    wordmark: 'Lore',
    eyebrow: 'Claude Code plugin · Beta',
    titleLead: 'Turn designs, briefs, and living products into',
    titleEmph: 'documentation that lasts',
    subtitle:
      'Lore is a reusable, product-agnostic documentation factory for Claude Code — the same skills, review subagents, and enforcement hooks, maintained once and consumed everywhere.',
    ctaPrimary: 'Get started',
    ctaSecondary: 'View on GitHub',
    installLabel: 'Install inside Claude Code',
  },
  problem: {
    eyebrow: 'Why Lore',
    title: 'Documentation rots, and every team rebuilds the same process.',
    body: 'Screens change, briefs drift, the live product moves on — and the docs quietly fall behind. Most teams reinvent their own writing rules, review steps, and folder conventions from scratch. Lore packages that whole methodology once: install the plugin and every repo inherits the same skills, the same Definition of Done, and the same guardrails.',
  },
  paths: {
    eyebrow: 'Three ways in',
    title: 'Start from whatever input you already have.',
    intro:
      'Pick the source that matches your material. Each path is a guided skill that reads the input, asks the right questions, and writes structured docs.',
    items: [
      {
        skill: 'figma-to-doc',
        name: 'From Figma',
        desc: 'Read design files, annotations, and comments. Extract individual frames as inline screenshots and turn them into documented flows and business rules.',
      },
      {
        skill: 'brief-to-doc',
        name: 'From a brief',
        desc: 'Work from a PRD, epic, or user story. Infer scenarios from acceptance criteria and log every clarification so gaps are explicit, not guessed.',
      },
      {
        skill: 'site-to-doc',
        name: 'From a live product',
        desc: 'Drive a real browser to run scenarios, capture screenshots, and record exact UI text — documenting how the product actually behaves today.',
      },
    ],
  },
  how: {
    eyebrow: 'How it works',
    title: 'From empty repo to published docs in four moves.',
    steps: [
      {
        cmd: '/lore:init',
        title: 'Scaffold',
        desc: 'Answer three questions — product name, language, and whether to add a Docusaurus viewer. The docs layer and rules are generated for you.',
      },
      {
        cmd: 'figma · brief · site',
        title: 'Generate',
        desc: 'Run the skill that matches your input. It collects sources, asks clarifying questions, and writes structured documentation.',
      },
      {
        cmd: 'doc-reviewer',
        title: 'Review',
        desc: 'Validate every document against the Definition of Done before delivery — links, image paths, scenarios, and language are all checked.',
      },
      {
        cmd: 'build',
        title: 'Deploy',
        desc: 'Ship Markdown-only docs, or build the static site and deploy the output to any host.',
      },
    ],
  },
  features: {
    eyebrow: 'What you get',
    title: 'A documentation factory, not just a template.',
    items: [
      {
        title: 'Blocking enforcement hooks',
        desc: 'Deterministic checks run on every file write — image paths, required frontmatter, and tooling leaks are caught before they reach the docs. A second family checks the evidence: a source claimed but never fetched blocks delivery.',
      },
      {
        title: 'A Definition of Done',
        desc: 'A read-only validator subagent audits each document against the rules and returns a pass/fail report — run automatically before delivery.',
      },
      {
        title: 'Multilingual & RTL ready',
        desc: 'Right-to-left languages get a self-hosted Persian font and proper layout out of the box — the same engine that powers this site’s documentation.',
      },
      {
        title: 'Maintained once, propagated everywhere',
        desc: 'Methodology lives in the plugin. Fix it once and every repo picks up the change with a single plugin update.',
      },
      {
        title: 'An optional Docusaurus viewer',
        desc: 'Keep Markdown-only docs, or add a browsable site whenever you want — the framework is fetched fresh, with RTL styling when needed.',
      },
      {
        title: 'Free QA on the side',
        desc: 'Documenting a live product surfaces real defects; Lore consolidates what it observes into structured bug drafts you can act on.',
      },
    ],
  },
  quickstart: {
    eyebrow: 'Quick start',
    title: 'Two commands to install, three questions to begin.',
    installTitle: 'Install (inside Claude Code)',
    installNote: 'Both steps are idempotent. Then enable Lore for your project.',
    initTitle: 'Scaffold your project',
    initNote:
      '/lore:init asks for a product name, a documentation language, and whether to add a Docusaurus viewer — then scaffolds everything without overwriting your files.',
  },
  dogfood: {
    text: 'The docs for this very site are built with Lore.',
    cta: 'Read the documentation',
  },
  footer: {
    tagline: 'A product-documentation factory for Claude Code.',
    product: 'Product',
    resources: 'Resources',
    docs: 'Documentation',
    github: 'GitHub repository',
    changelog: 'Changelog',
    license: 'License',
    rights: 'Released under the MIT License.',
    builtWith: 'Docs built with Lore.',
  },
};

export type Content = typeof t;
