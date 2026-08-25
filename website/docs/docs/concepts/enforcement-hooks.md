---
sidebar_position: 3
title: Enforcement hooks
description: Deterministic, blocking hooks that check the shape of what was written and the evidence that the work behind it actually happened.
tags: [concepts, hooks, enforcement]
---

# Enforcement hooks

Skills and subagents do the writing; **hooks make the rules deterministic.** Lore ships shell-script hooks that run automatically — on every file write, when a subagent finishes, and at the end of a turn — and *block* the work when a rule is violated, feeding back exactly what to fix.

They fall into two families, and the distinction is the whole design:

- **Output enforcers** ask *is the markdown shaped right?*
- **Evidence enforcers** ask *did the work behind it actually happen?*

The second family exists because of a specific failure. A rule enforced only by prose is enforced by nothing: the agent that skipped a step is the same agent that writes the report saying it didn't, so an obligation discharged by writing a sentence always passes. `nothing relevant — confirmed searched` is byte-identical whether a source was read or never opened.

## Output enforcers — on every write

| Hook | Blocks when… |
|------|--------------|
| **Frontmatter check** | A documentation file is missing its required frontmatter (a closed YAML block with the expected keys). |
| **Image-path check** | An image is written into the docs folder, a Markdown image reference uses the wrong path prefix, or a mobile screenshot is embedded with Markdown syntax instead of a raw `<img>` tag (the build rewrites the former and the mobile styling stops applying). |
| **Tooling-reference check** | A published doc mentions the authoring tooling — internal paths, configuration citations, or skill names. (Reader-facing output stays self-contained — see [Division of responsibility](./division-of-responsibility.md).) |

## Evidence enforcers — did the work happen?

| Hook | What it does |
|------|--------------|
| **Evidence recorder** | Never blocks. Appends one line per fetch and subagent run to an append-only log. **You don't write this file** — the tooling does — so a source that was never fetched does not appear in it by accident. Entries are *tiered*: a fetch a tool actually performed counts as evidence; a URL that merely appeared inside a shell command does not. |
| **Census check** | Blocks a source census whose rows have no receipt (the probe, its HTTP status, the saved raw payload), whose cited payloads are missing, whose claimed sources have no verified fetch behind them, or which records a zero the raw payload contradicts. |
| **Validator recorder** | Never blocks. Records each review run: its verdict, **which files it actually reviewed**, and a fingerprint of every documentation page as it stood at that moment. Also keeps an append-only history of every run. |
| **Census reminder** | Never blocks. When a new page is created and no census exists yet, it restates the obligation at the moment of the action. |
| **Bulk-edit reminder** | Never blocks. Before a tree-wide identical edit of your documentation, it surfaces the checks that class of edit needs — because nothing in it is *mis-typed*, so no output check can see the damage. |

### Validated twice, at different strictnesses

A census is written incrementally — the run contract goes in at pre-flight, before anything has been fetched — so judging it once would be wrong in one direction or the other:

- **On write, the check validates *shape*.** Is what has been written so far well formed and receipted? This lets the pre-flight census exist.
- **At the end of the turn, it validates *completeness*.** The run is over, so every source type the input demands must now carry a real count, and a live-site run must show the states it actually observed.

Enforcing completeness at write time blocked the very first write, and the cheapest way out of that block was a placeholder — which then satisfied the check for the rest of the run. The gate ended up teaching the model to disarm the gate.

## At the end of a turn

A **Stop** hook does the final sweep. It blocks on misplaced images and bad image references, and — in a project where a producing run left evidence behind — on:

- a session that wrote documentation but left **no source census at all**;
- a census that is still incomplete;
- an explicit user instruction still open in the run contract (`satisfied` needs evidence beside it; `waived` needs your approval);
- documentation whose **content** differs from what the last green review actually judged.

It also warns about images nothing references, and it is loop-aware so it won't trap you on an unfixable violation.

### A change after a green review is your call, not another round

The last check used to compare timestamps, which was wrong in both directions. A `git pull`, a rebase or an editor save that restores identical bytes forced a whole re-validation round for nothing — and when something genuinely *had* changed, the only available response was "run it again", so a one-word typo fix and a sweeping find-and-replace were treated identically. Neither reached you.

It now compares content, page by page:

- **an unchanged rewrite is a non-event** — no round, no prompt;
- **a real change stops the turn and comes to you.** You are told which files changed and what the risk is, and you choose: re-review exactly those files, or approve delivering as they are.

Your approval is recorded against that exact content, so a further edit quietly retires it — an approval can never stretch to cover a change you never saw. And it cannot override a failed review: a blocking verdict has to be fixed, not waived.

Resist the instinct that "it was only a spelling fix". The rule exists because of one: a single word replaced across a project landed inside quoted interface text and silently falsified twenty-one pages, while every changed line still read correctly on its own.

## Scope and safety

- **Hooks act only in a Lore documentation project.** A plugin is installed per user, so its hooks run in whatever repository you happen to be working in. Every hook therefore checks for a Lore project first and exits immediately otherwise. The rules here are Lore's Definition of Done, not universal truth — a project that never adopted them is untouched, even if it happens to keep Markdown or images in a folder named `docs`.
- Within a Lore project, hooks act only on the documentation folder, resolved relative to the project root. Intentional examples under template directories are carved out and skipped.
- Parsing degrades gracefully across available tools and warns loudly if none is present, rather than silently passing.

## What these gates are, and are not

They guard against a step being **skipped**, not against deliberate forgery. Every artifact involved is an ordinary file, and an agent with shell access can write one. The property they buy is that false evidence is not something that appears *by accident* during normal work — which is exactly the failure mode they were built for. Claiming more than that would repeat the mistake that made an earlier release believe it had already fixed this.

## Known limits

- A source fetched before you upgraded is not in the log, so the first run afterwards re-fetches it.
- Matching claimed sources against the log is by host — deliberately permissive, to keep false blocks near zero.
- Documentation written outside the normal file tools leaves no session marker and is therefore not process-gated.

The result: the most common documentation mistakes — wrong image paths, missing frontmatter, tooling leaks — are caught immediately; and the far more expensive mistake, a source silently skipped and then certified as checked, no longer has a quiet path to delivery.
