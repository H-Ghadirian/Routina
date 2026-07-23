# 0001 — Number mixed timeline entries in display order

Date: 2026-07-23

## Symptom

Recent focus activities in the Mac Timeline showed large row numbers while nearby task activities started at 1, so the visible rows did not form one continuous sequence.

## Root Cause

Timeline entries are initially assembled by entity category, with task logs before focus sessions and other activity types. The row-number lookup used that intermediate order, but the list rendered a later day-grouped, reverse-chronological order.

## Fix

Row numbers are now derived from the already-built grouped presentation snapshot, flattened in the same section and entry order used by the list.

## Prevention Rule

Derive positional metadata such as row numbers from the final display ordering, never from an intermediate collection whose order can differ from the rendered presentation.

## Regression Safeguard

`TimelineLogicTests.rowNumbersFollowGroupedDisplayOrderAcrossEntryTypes` verifies that a newer focus entry receives row 1 even when the input collection contains an older task log first.
