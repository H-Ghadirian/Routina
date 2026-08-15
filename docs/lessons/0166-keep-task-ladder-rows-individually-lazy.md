# 0166 — Keep Task Ladder rows individually lazy

Date: 2026-08-15

## Symptom

Scrolling a Mac Task Ladder with about 136 tasks to its final rows could leave
Routinam visually stuck while one CPU core remained saturated and resident
memory grew far beyond the normal idle footprint.

## Root Cause

The Task Ladder's outer `LazyVStack` treated each metric section as one child,
while that child contained an eager `VStack` of every task in the section. At
the bottom of a tall section, SwiftUI repeatedly measured that entire composite
child backwards and churned lazy-item phases through AttributeGraph. A live
five-second sample found the main thread entirely inside SwiftUI layout, with
`LazyStack.resolveIndexAndPosition`, `StackPlacement.measureBackwards`, and
`LazyLayoutViewCache.updateItemPhases` dominating the loop.

## Fix

Metric headers and their `ForEach` task rows are now direct `Section` content of
the scrolling `LazyVStack`. Each task remains an independently managed lazy
child instead of contributing to one full-height eager section child.

## Prevention Rule

Never wrap an unbounded collection of rows in an eager stack and then place only
that wrapper inside a lazy scrolling container. The lazy container must own the
individual row identities it needs to virtualize and position.

## Regression Safeguard

`TaskRankingPresentationTests.taskLadderKeepsRowsAsDirectLazySectionContent`
guards the structural boundary, and the Task Ladder performance scenario
requires bottom-of-list verification with production-like task volume.
