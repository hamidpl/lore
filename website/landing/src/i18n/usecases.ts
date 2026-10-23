/* ---------------------------------------------------------------------------
   One landing page per input (/figma-to-docs/, /prd-to-docs/,
   /live-site-to-docs/), each aimed at what people search for. Every claim is a
   summary of the matching docs guide (website/docs/docs/guides/*) — change the
   guide first, then this; nothing here may say more than the guide does.
   --------------------------------------------------------------------------- */

import { SITE } from '../config';

export interface UseCaseSection {
  heading: string;
  ordered?: boolean;
  items: string[];
}

export interface UseCase {
  slug: string;
  skill: string;
  cardLabel: string;
  metaTitle: string;
  metaDescription: string;
  title: string;
  lead: string;
  command: string;
  prereq?: { text: string; command: string };
  sections: UseCaseSection[];
  notes: string[];
  guideUrl: string;
  guideLabel: string;
}

export const USE_CASES: UseCase[] = [
  {
    slug: 'figma-to-docs',
    skill: 'lore:figma-to-doc',
    cardLabel: 'Figma to documentation',
    metaTitle: 'Figma to Product Documentation with Claude Code | Lore',
    metaDescription:
      'Turn Figma files, Dev-Mode annotations, comments and prototype flows into product documentation with scenarios, business rules and screenshots, in Claude Code.',
    title: 'Turn Figma designs into product documentation',
    lead: 'lore:figma-to-doc reads a Figma file the way a careful writer would (its comments, its Dev-Mode annotations, its prototype wiring) and turns it into structured documentation: numbered scenarios, explicit business rules, and the frames themselves as inline screenshots.',
    command: 'lore:figma-to-doc <figma-url-or-file-key>',
    sections: [
      {
        heading: 'What it reads',
        items: [
          'Discussion comments and Dev-Mode annotations: two separate sources, and both are read.',
          'Prototype flows and each frame’s interactions, as navigation evidence for the main flow instead of guessing it from frame names.',
          'Every frame in scope, exported individually at 2× and sorted into desktop, tablet and mobile.',
          'Your configured trusted sources, searched for material about the pages in scope.',
        ],
      },
      {
        heading: 'How a run works',
        ordered: true,
        items: [
          'Collect sources. Each one is recorded in a source census with the receipt behind it, so no source can be silently skipped.',
          'Review the design. Every frame is visited, out-of-scope pages are skipped, and the business rules in annotations and comments are summarised.',
          'Write. Figma pages map to sections, frame groups to numbered scenarios, annotations to business rules, and prototype interactions to main-flow steps, with a Mermaid diagram wherever a section has two or more interaction edges.',
          'Validate. The doc validator checks the result against the Definition of Done before delivery, and the run ends with a source and tooling report.',
        ],
      },
      {
        heading: 'When the design is incomplete',
        items: [
          'Missing information becomes an explicit [CLARIFICATION NEEDED] marker, never a guess.',
          'States the design does not show (empty, error, loading, permission-denied) become questions, never invented screens.',
          'When an annotation and a comment disagree, the annotation wins and the conflict is raised with you.',
          'Placeholder or Lorem Ipsum text prompts a request for the real content.',
        ],
      },
      {
        heading: 'What you get',
        items: [
          'Markdown documentation with numbered scenarios and explicit business rules.',
          'Individual frame screenshots, compressed in one pass: typically around 70% smaller at the same dimensions.',
          'A Mobile & Tablet View section when the design includes those frames.',
          'A final report of the sources read, the tooling used and the open questions.',
        ],
      },
    ],
    notes: [
      'Large files are handled by the lore:figma-extractor subagent, which returns a compact summary so the main session’s context stays clean.',
      'The Figma token is read from the environment or the connected integration. It is never requested in chat or written to a file.',
    ],
    guideUrl: `${SITE.docsUrl}/guides/from-figma/`,
    guideLabel: 'Read the Figma guide',
  },
  {
    slug: 'prd-to-docs',
    skill: 'lore:brief-to-doc',
    cardLabel: 'PRD to documentation',
    metaTitle: 'PRD to Product Documentation with Claude Code | Lore',
    metaDescription:
      'Turn PRDs, briefs, epics and user stories into product documentation: scenarios from acceptance criteria, explicit business rules and the states left to design.',
    title: 'Turn PRDs and user stories into product documentation',
    lead: 'lore:brief-to-doc works from written requirements (a product brief, PRD, epic or user story) and documents what they state. What they leave out is marked as a question, not filled in with a guess.',
    command: 'lore:brief-to-doc <brief-text-or-file>',
    sections: [
      {
        heading: 'What it reads',
        items: [
          'The brief end to end: every user story and acceptance criterion.',
          'Your configured trusted sources, actually fetched and searched for the features in scope.',
          'What you asked for in conversation, written down as numbered rows before reading starts. The run cannot be delivered while one is still open.',
        ],
      },
      {
        heading: 'How a run works',
        ordered: true,
        items: [
          'Check readiness. If acceptance criteria, roles or out-of-scope statements are missing, it says so before writing and continues only with your go-ahead.',
          'Ask. A handful of high-impact clarifying questions; the rest become explicit placeholders instead of a wall of questions.',
          'Infer scenarios. “As a [role], I want [action], so that [benefit]” becomes purpose, preconditions, flow and postconditions; Given/When/Then criteria map onto them structurally.',
          'Walk the edge cases. Every scenario is checked against the edge-case taxonomy (empty states, boundaries, loading, concurrency, permissions and more).',
          'Validate and report, including a log of every clarification raised.',
        ],
      },
      {
        heading: 'When the brief is incomplete',
        items: [
          'A subjective criterion such as “fast” or “good UX” is never accepted as a rule; it is flagged with a suggested measurable formulation.',
          'Features are never invented. A gap points to an existing documented pattern, describes behaviour rather than appearance, or asks for a mockup.',
          'Unanswered questions are collected under Pending Questions in the final report.',
        ],
      },
      {
        heading: 'What you get',
        items: [
          'Scenarios with purpose, preconditions, flow, postconditions and extensions.',
          'Acceptance criteria rewritten as explicit business rules.',
          'A States to Design table: every state the feature needs, marked specified, unspecified or designed, so a designer gets one flat checklist.',
          'A final report with the clarification log.',
        ],
      },
    ],
    notes: [
      'A brief has no visuals, so expect more clarification markers than a design-based run. That is the point: the gaps are visible instead of guessed.',
    ],
    guideUrl: `${SITE.docsUrl}/guides/from-a-brief/`,
    guideLabel: 'Read the PRD and brief guide',
  },
  {
    slug: 'live-site-to-docs',
    skill: 'lore:site-to-doc',
    cardLabel: 'Live site to documentation',
    metaTitle: 'Document a Live Website with Claude Code and Playwright | Lore',
    metaDescription:
      'Document how your product actually behaves: drive a real browser with Playwright, run scenarios, capture screenshots and exact UI text, and get bug drafts too.',
    title: 'Document how your product actually behaves',
    lead: 'lore:site-to-doc observes the live product in a real browser. It runs scenarios, records the exact UI text and captures screenshots, so the documentation describes what users see today rather than what a spec once said.',
    command: 'lore:site-to-doc <product-url>',
    prereq: {
      text: 'It drives a real browser through the Playwright MCP server. Add it once:',
      command: 'claude mcp add playwright -- npx @playwright/mcp@latest',
    },
    sections: [
      {
        heading: 'How a run works',
        ordered: true,
        items: [
          'Pre-flight. Pins the routes and features to explore and asks once whether to add a responsive pass (mobile 390×844, tablet 768×1024, or both).',
          'Scenario scripts. Each feature gets a small, re-runnable list of steps: an action, a screenshot name, and optional text to wait for.',
          'Browse. The lore:site-explorer subagent performs the steps, reads the exact UI text from the accessibility snapshot and captures deterministic screenshots.',
          'Validate and report.',
        ],
      },
      {
        heading: 'What it covers',
        items: [
          'The happy path, end to end.',
          'Validation errors, with the exact error text recorded.',
          'Edge cases: limits probed just below, at and just above (99/100/101), Back mid-flow, direct URL entry into a mid-flow state, empty states and network failures.',
          'Roles and permissions, and every authentication state as a product of its own: which states were actually reached is recorded, so a guest-only run is visible as one.',
        ],
      },
      {
        heading: 'What you get',
        items: [
          'Documentation with consistent, diffable screenshots (1280×720 by default) and UI text read from the accessibility tree, not pixels.',
          'A Mobile & Tablet View section when you opt into a responsive pass.',
          'Bug drafts for real defects it observes (title, severity, steps to reproduce, screenshot), optionally filed as GitHub issues.',
          'Screenshots compressed in one batch: typically around 70% smaller at the same dimensions.',
        ],
      },
    ],
    notes: [
      'If a feature needs a login, you sign in once in the headed browser and the session persists.',
    ],
    guideUrl: `${SITE.docsUrl}/guides/from-a-live-site/`,
    guideLabel: 'Read the live-site guide',
  },
];
