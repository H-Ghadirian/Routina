# 0211 — Persist the reminder from the active Quick Add preview

Date: 2026-08-20

## Symptom

Choosing two hours before in the Mac Quick Add preview and pressing Enter could create the dated task without the reminder appearing later in Edit Task.

## Root Cause

The Enter action parsed the toolbar search again instead of using the exact draft already attached to the interactive preview. Focus and menu interactions could make that submit-time lookup stale or unavailable, causing the reminder lead-time calculation to receive no event date.

## Fix

Pass the preview's parsed draft into its Enter handler and calculate the selected reminder from that snapshot before starting the asynchronous save.

## Prevention Rule

Interactive previews that offer derived choices must submit the same validated presentation snapshot the person acted on; do not re-derive the source state after focus or menu interaction.

## Regression Safeguard

The Mac presentation tests verify that the two-hour choice produces the expected reminder relative to the preview event date. The shared Quick Add persistence test verifies that the resulting `RoutineTask` stores the reminder and keeps the exact availability without a deadline.
