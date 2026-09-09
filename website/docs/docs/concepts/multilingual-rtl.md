---
sidebar_position: 4
title: Multilingual & RTL
description: How Lore supports multiple languages and right-to-left layouts, with a self-hosted Persian font, driven by the documentation language.
tags: [concepts, i18n, rtl]
---

# Multilingual & RTL

The documentation language is a first-class choice, set at [`/lore:init`](../getting-started/quick-start.md) and changeable with [`/lore:config`](../getting-started/configure.md). It drives both content and styling.

## Language drives styling

- **Right-to-left languages** (Persian, Arabic, …) get a right-to-left layout and a **self-hosted [Vazirmatn](https://github.com/rastikerdar/vazirmatn) Persian font**, applied automatically.
- **Left-to-right languages** get stock styling.

The font is self-hosted with relative URLs, so it resolves correctly even under a sub-path deploy — no external font CDN, no broken paths.

## How it's layered

When the Docusaurus [viewer](../guides/add-docusaurus.md) is present, the RTL support is a separate stylesheet layered *after* the generic styling and scoped to `html[dir='rtl']`. The base styling stays language-agnostic; the RTL layer adds the Persian font stack and the right-to-left adjustments (menus, tables, admonition accents, footer). One project can therefore carry both directions cleanly.

## How the prose itself is governed

Layout is only half of it. Documentation written in a language other than the source's reads as *translated* long after the translation is accurate — English punctuation habits and sentence shapes carry straight over. So the Definition of Done defers: when a writing skill for your documentation language is available in the session, it is the authority on that language's prose and orthography, and Lore restates none of its rules. For Persian that skill is [`persian-writing`](https://github.com/ali2000hos/persian-writing).

What Lore keeps is only what such a skill cannot know — the constraints its own output format imposes. For a right-to-left language there are two:

- **Ordered-list markers stay ASCII** (`1.`, never `۱.`). CommonMark recognises only `0-9` as a list marker, so a localised one renders as literal text and the list stops being a list. Digits in headings and prose follow the language skill, not this rule.
- **A `U+200F` RLM before a token that opens with a neutral character** (a `/`, or a code span whose content starts with one) has to survive editing. The bidi algorithm gives a leading neutral the paragraph direction and flips the token. An RLM before a strong left-to-right letter does nothing and can go.

A language skill's own linter is advisory, not authoritative: read each finding before applying it, and do not run a bulk auto-fixer over the tree.

## This site is the proof

The documentation you are reading is bilingual — English and Persian — built on exactly this mechanism. Use the language dropdown in the navigation bar to switch; the Persian version flips to a right-to-left layout in the Vazirmatn font.

:::note Font license
Vazirmatn is bundled under the SIL Open Font License 1.1, separate from Lore's own MIT license.
:::
