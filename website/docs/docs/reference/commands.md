---
sidebar_position: 1
title: Commands
description: Reference for Lore's slash commands — /lore:init, /lore:config, and /lore:add-docusaurus.
tags: [reference, commands]
---

# Commands

Lore provides three slash commands, run inside Claude Code.

## `/lore:init`

Scaffold a new documentation project (interactive wizard).

- Asks three essentials: **product name**, **documentation language**, and **whether to install a Docusaurus viewer**.
- Generates the documentation layer (`docs/` and the project's configuration), and optionally a Docusaurus site.
- Never overwrites existing files — safe to run in an existing repository.

→ [Quick start](../getting-started/quick-start.md)

## `/lore:config`

Fill in or edit a project's settings, anytime. Every question is optional and the command is idempotent.

- Project site URL, product description, trusted sources, document-writing template, brand color.
- Re-apply product name or documentation language.
- Turn the Docusaurus viewer on or off.

→ [Configure a project](../getting-started/configure.md)

## `/lore:add-docusaurus`

Add the Docusaurus viewer to an existing docs-only project.

- Fetches the latest Docusaurus, overlays Lore's configuration and styling, and wires the sidebar to your docs.
- Adds the RTL layer and Persian font when the documentation language is right-to-left.

→ [Add the Docusaurus viewer](../guides/add-docusaurus.md)
