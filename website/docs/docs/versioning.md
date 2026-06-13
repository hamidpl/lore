---
sidebar_position: 6
title: Versioning & releases
description: How Lore is versioned — semantic versioning, the pre-1.0 status, and how to pin a stable version.
tags: [versioning, releases]
---

# Versioning & releases

Lore follows [semantic versioning](https://semver.org). The current version is recorded in the plugin manifest, and changes are listed in the [changelog](https://github.com/hamidpl/lore/blob/main/CHANGELOG.md).

## Pre-1.0

Lore is **pre-1.0**. It works end to end, but minor releases may include breaking changes until `1.0.0`. If you need stability, pin to a fixed version.

## Pinning a version

Add the marketplace at a fixed git tag:

```text
/plugin marketplace add hamidpl/lore#v0.1.0
```

Pinning means you won't pick up changes — including fixes — until you deliberately move the pin.

## Staying current

When you're tracking the latest release:

```text
/plugin marketplace update lore-marketplace
claude plugin update lore@lore-marketplace
```

See [Install & enable](./getting-started/install.md) for the full update flow. Each release is tagged and published; the [changelog](https://github.com/hamidpl/lore/blob/main/CHANGELOG.md) is the source of truth for what changed.
