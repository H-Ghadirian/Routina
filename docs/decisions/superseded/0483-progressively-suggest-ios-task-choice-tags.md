# 0483: Progressively Suggest iOS Task-Choice Tags

## Status

Superseded by [0485 Remove Opt-In Tag Preferences Pending Automatic Tag Intelligence](../0485-remove-opt-in-tag-preferences-pending-automatic-tag-intelligence.md).

## Date

2026-08-06

## Refines

[0482 Use Opt-In Tag Preferences to Refine iOS Task Choice](0482-use-opt-in-tag-preferences-to-refine-ios-task-choice.md)

## Context

An alphabetical catalogue of every task tag asks a person to predict a future
preference before Routina has any evidence. Many tags are one-off labels and
are not meaningful work areas, so making the entire catalogue the initial
setup creates unnecessary uncertainty.

## Decision

Tag preferences begin with no tags selected. The iOS entry shows only broad
tags that appear on at least three currently selectable tasks, plus a separate
section for any already enabled specific tag. A searchable `Manage all tags`
destination remains available for deliberate advanced selection.

Help me choose first learns the existing individual task tie-breaks. When two
or more separately preferred active tasks share an unused broad tag, it offers
one contextual prompt to opt that tag into future suggestions. `Not now`
leaves the tag unselected; no tag is inferred or enabled automatically.

The existing opt-in scoring, rank order, sync, backup, rename, and deletion
rules from 0482 remain unchanged. This is an iOS-only interface and ranking
behavior.

## Consequences

- People can use Help me choose immediately without deciding what every tag
  means.
- Tags become a refinement the product can explain from demonstrated choices,
  while the person remains in control of opting in.
- Specific or one-off tags remain available without dominating the first
  screen.
