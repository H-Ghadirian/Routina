# 0008 — Keep Assumed Completion Visually Distinct From Recorded Completion

Date: 2026-07-24

## Symptom

Auto-assumed Tracking rows in the Mac Home sidebar showed a green `Done` badge
instead of `Assumed`. Their status badges also sat too far from the trailing
edge, and hidden hover actions compressed the row title.

## Root Cause

The shared Home display intentionally includes an assumed occurrence in
`isDoneToday` for list placement. The badge presenter checked that broader flag
before checking `isAssumedDoneToday` for soft-interval Tracking rows. Separately,
the Mac row permanently reserved the width of the confirm and missed hover
buttons even though those buttons were already drawn in an overlay.

## Fix

Badge presentation now gives the explicit assumed state precedence over the
broader done state. Mac task rows reserve trailing space only for a visible
color marker; assumed-day actions overlay the trailing row content when hovered.

## Prevention Rule

When a presentation model carries both a broad classification flag and a more
specific state flag, render the specific state first. Overlay-only hover
controls must not reserve layout width unless persistent content needs to remain
visible beside them.

## Regression Safeguard

The shared badge-presentation test covers a Tracking row whose display is both
done and assumed and requires the `Assumed` badge. The documented Home scenario
also requires overlay hover actions without permanent trailing space.
