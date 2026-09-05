# 0742 — Externalize Stats Achievement Copy

## Status

Accepted

## Date

2026-09-05

## Refines

- [0131 — Show General Achievement Badges](0131-show-general-achievement-badges.md)
- [0719 — Externalize Localizable and Structured Product Copy](0719-externalize-localizable-and-structured-product-copy.md)

## Context

Stats defines 68 derived achievements across Focus, Sleep, Away, Done,
Emotions, Places, Goals, and Notes. Their titles, explanations, and count-unit
words were repeated inside the same large Swift declarations that calculate
progress. That mixed content authoring with thresholds and domain logic, kept
two calculation files above 500 lines, and left runtime-created strings outside
the compiler's normal SwiftUI localization extraction.

The achievement IDs, target thresholds, metric inputs, categories, and SF
Symbols are behavior or presentation structure. Moving those values into a
content file would make translation edits capable of changing badge identity or
unlock behavior.

## Decision

Routina stores achievement titles, subtitles, optional subtitle variants, and
singular/plural count-unit words in
`SharedCore/Resources/en.lproj/StatsAchievementContentCatalog.json`.

Swift keeps stable IDs, target values, current-value derivation, domains,
categories, and symbols. A typed loader validates nonempty content and unique
IDs, builds one immutable lookup dictionary, and fails the development
invariant when calculated achievement code requests a missing entry or count
unit. Tests require the resource ID set to equal the complete generated
achievement set and preserve the Places-dependent subtitle variant.

Shared achievement models live separately from the calculation file so model,
content-loading, and metric derivation have distinct ownership.

## Consequences

- Translators and reviewers can inspect all achievement wording in one bounded
  resource without navigating calculation code.
- Editing copy cannot silently change achievement IDs, thresholds, categories,
  symbols, or progress calculations.
- Missing, duplicate, or incomplete content fails fast during development.
- Both achievement calculation files remain below 500 lines while retaining
  their domain algorithms in Swift.
