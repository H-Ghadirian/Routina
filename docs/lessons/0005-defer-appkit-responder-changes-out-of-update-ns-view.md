# 0005 — Defer AppKit responder changes out of `updateNSView`

## Symptom

Clicking the animated macOS toolbar search field logged:
`Modifying state during view update, this will cause undefined behavior.`

## Root Cause

The search representable called `makeFirstResponder` while SwiftUI was executing
`updateNSView`. AppKit synchronously invoked text-field delegate callbacks, which
wrote the SwiftUI focus binding before the view-update transaction had ended.

## Fix

Focus and dismissal request IDs are captured during `updateNSView`, then applied
on the next main-queue turn. The coordinator still deduplicates handled request
IDs, so queued representable updates cannot replay an old focus request.

## Prevention Rule

Never perform an AppKit operation from `updateNSView` when it can synchronously
invoke a delegate or notification callback that writes SwiftUI state. Schedule
that operation after the representable update returns.

## Regression Safeguard

The macOS performance regression suite verifies that toolbar-search responder
requests are dispatched asynchronously instead of being applied inline.
