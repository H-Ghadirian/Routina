# 0655: Separate Mac Task Detail Actual Time and Focus Controls

## Status

Superseded by [0657: Make Mac Task Detail Effort a Compact Summary and Action Surface](../0657-make-mac-task-detail-effort-a-compact-summary-and-action-surface.md)

## Date

2026-08-24

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0651: Keep Task Focus Separate From Actual Time](0651-keep-task-focus-separate-from-actual-time.md)
- [0652: Keep Effort Fields Independent and Disclosures Honest](0652-keep-effort-fields-independent-and-disclosures-honest.md)
- [0653: Present Effort Values as Values, Not Feature Switches](0653-present-effort-values-as-values-not-feature-switches.md)

## Context

Mac one-off Task Details grouped Actual time and Focus under Effort, but the
expanded card gave them one duration stepper and one action row. The same value
could be logged as Actual time or used to start a Focus countdown, while Count
up appeared beside a duration it ignored. This presentation made independent
records look coupled even though their persistence and history were already
separate.

The combined picker also stored one local last-duration preference, so Routina
could not know whether that value represented the person's last manual time
entry or Focus countdown choice.

## Decision

- Mac one-off Task Details present separate `Actual time` and `Focus timer`
  areas inside expanded Effort.
- Actual time owns its duration input, 15/30/60-minute presets, remembered
  value, and Log/Add/Edit-total actions. A new entry defaults to 30 minutes and
  does not inherit Estimate.
- Focus owns a Countdown/Count up mode choice and a separate remembered
  countdown duration. Countdown defaults to 25 minutes and offers 25/45/60
  presets; Count up does not show a duration selector.
- Starting or blocking Focus replaces Focus start controls with the running or
  unavailable status. It does not disable Actual-time logging or present
  unusable Focus buttons.
- The ambiguous former combined-duration preference is not migrated into
  either new preference because its meaning cannot be recovered safely.
- These presentation and local-preference changes do not combine Actual time
  with Focus history or alter either persistence model.

## Consequences

- Every visible duration input has one clear destination.
- Count up no longer appears to use an ignored duration.
- Estimate, Actual time, and Focus retain independent defaults and remembered
  choices.
- Active and externally blocked sessions retain clear status and controls
  without competing start actions.

## Supersession Note

Decision 0657 preserves the independent Actual-time and Focus state established
here, but moves their inputs out of the permanently expanded card and into
focused popovers. It also replaces the embedded history dashboard with compact
rows and keeps Focus available after the first retained session.
