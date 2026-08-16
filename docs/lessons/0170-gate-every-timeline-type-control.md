# 0170 — Gate every Timeline type control

Date: 2026-08-16

## Symptom

iOS Timeline's Type picker offered Events, Emotions, and Sleep while their
feature flags were off and those features were unavailable elsewhere in the
app. The horizontal Timeline type controls exposed the same unavailable
choices, and a restored hidden selection could remain active.

## Root Cause

The shared Timeline filter model already accepted Event/Emotion and Sleep
availability, but the iOS view hard-coded Event/Emotion availability to true
and relied on the default true value for Sleep. Feature-gated creation and
Settings surfaces were updated without wiring the same inputs into every
Timeline type-filter presentation and normalization path.

## Fix

iOS Timeline now derives its picker choices, horizontal type controls, parent
Type-row visibility, effective filter, and stale-selection normalization from
the Event/Emotion, Away, and Sleep flags. It revalidates when those flags
change and when the retained Timeline becomes active.

## Prevention Rule

When a shared option builder accepts feature-availability inputs, every
platform presentation, binding getter/setter, restored-state normalizer, and
active-filter summary must pass the same effective availability values. Never
rely on permissive default arguments for optional product features.

## Regression Safeguard

`IOSNewTabActionAvailabilityTests.timelineTypeFiltersFollowFeatureAvailability`
guards the iOS wiring, while `TimelineLogicTests` protects the shared option
filtering and hidden-selection normalization semantics. The iOS Timeline Type
Filters scenario records the end-to-end expectation.
