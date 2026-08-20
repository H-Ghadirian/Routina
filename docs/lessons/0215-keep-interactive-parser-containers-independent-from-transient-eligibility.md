# 0215 — Keep interactive parser containers independent from transient eligibility

Date: 2026-08-20

## Symptom

Once Mac Quick Add showed Detected details, continuing to type could make the whole rectangle disappear and reappear even though the title and reminder state survived.

## Root Cause

The same transient computed draft controlled both parser content and whether the interactive container existed. Async search refreshes and incomplete syntax legitimately made that draft nil, so SwiftUI removed and later recreated the entire preview.

## Fix

The first confirmed detected draft now pins the preview for the active composition. Subsequent parsable drafts replace only its contents, an unparsable intermediate value renders a noninteractive updating state, and confirmed existing search results or composition-ending actions remove the presentation.

## Prevention Rule

Do not let transient parser or network eligibility own the structural identity of an interactive editor. Pin the container for the user session, reconcile its content separately, and reserve removal for explicit lifecycle boundaries.

## Regression Safeguard

`RoutinaQuickAddParserTests` verifies that preview pinning begins only when allowed, adopts later drafts without detected metadata, survives an unparsable intermediate value, and clears with empty input. The Mac source regression requires pinned presentation identity, confirmed-result dismissal, and the noninteractive updating copy.
