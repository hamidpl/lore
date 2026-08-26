---
sidebar_position: 6
title: Versioning & releases
description: How Lore is versioned — semantic versioning, what a major release means, and how to pin a fixed version.
tags: [versioning, releases]
---

# Versioning & releases

Lore follows [semantic versioning](https://semver.org). The current version is recorded in the plugin manifest, and changes are listed in the [changelog](https://github.com/hamidpl/lore/blob/main/CHANGELOG.md).

## What each release can change

- **Patch** — fixes only. Safe to take.
- **Minor** — new skills, hooks, or template content, backward compatible. Existing projects keep working; the methodology file is re-synced automatically, so improved rules reach a project it is already installed in.
- **Major** — the only place a breaking change lands: a removed or renamed command, an incompatible template layout, or a rule that changes what an existing project must do to deliver.

## Pinning a version

Add the marketplace at a fixed git tag:

```text
/plugin marketplace add hamidpl/lore#v1.0.0
```

Pinning means you won't pick up changes — including fixes — until you deliberately move the pin.

## Staying current

When you're tracking the latest release:

```text
/plugin marketplace update lore-marketplace
claude plugin update lore@lore-marketplace
```

See [Install & enable](./getting-started/install.md) for the full update flow. Each release is tagged and published; the [changelog](https://github.com/hamidpl/lore/blob/main/CHANGELOG.md) is the source of truth for what changed.
