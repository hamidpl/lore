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

## This site is the proof

The documentation you are reading is bilingual — English and Persian — built on exactly this mechanism. Use the language dropdown in the navigation bar to switch; the Persian version flips to a right-to-left layout in the Vazirmatn font.

:::note Font license
Vazirmatn is bundled under the SIL Open Font License 1.1, separate from Lore's own MIT license.
:::
