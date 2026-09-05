# 0300 — Preserve geometry across semantic state transitions

Date: 2026-09-05

## Symptom

Confirming an assumed completion in iOS Task Details made the visible page jump.
The primary completion control could briefly appear blank and then show a dimmed
Undo before reaching its final orange state.

## Root Cause

One semantic action changed multiple independently sized views above the pressed
control. The conditional assumed-status pill was removed, and the Status value
changed from a wrapped two-line phrase to a one-line phrase. The completion label
also changed structural view shape when it gained the Undo symbol. Although the
domain reducer updated completion optimistically, the presentation exposed these
intermediate geometry and identity changes.

## Fix

Task Detail now records a presentation-only acknowledgement when an assumed day
is confirmed. The assumed pill becomes `Confirmed` within the same view, and the
Status badge measures its previous value invisibly until the detail presentation
ends. Enabled iOS completion actions keep an icon-and-text label before and after
the action, with animation scoped to content and disabled under Reduce Motion.

## Prevention Rule

When one action changes semantic labels or conditional content above the current
viewport, preserve the relevant view identity and transition geometry. Derive a
temporary size reservation from the actual previous content instead of using a
fixed height, global scroll correction, or permanent empty space.

## Regression Safeguard

`TaskDetailFeatureCompletionTests` verifies that confirming an assumed day creates
the in-session acknowledgement. `TaskDetailTransitionPresentationTests` verifies
that the confirmed Status badge reserves its previous value, and
`TaskDetailPlatformActionParityTests` protects the stable iOS pill and completion
label structure. The iOS Task Detail scenario records the expected no-jump and
Reduce Motion behavior.
