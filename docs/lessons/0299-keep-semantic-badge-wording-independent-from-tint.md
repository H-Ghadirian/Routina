# 0299 — Keep semantic badge wording independent from tint

Date: 2026-09-05

## Symptom

In dark-mode iPhone Backlog rows, task-type and lifecycle pills looked like
unexplained blue, green, orange, red, or gray symbols. Their intended wording did
not remain visually clear enough for a person to understand the badges.

## Root Cause

The shared row rendered each badge as a tinted `Label`, applying the same semantic
color to both symbol and small caption text over a tinted fill. The visual design
made color dominant and treated the explanatory wording as a weak secondary cue.

## Fix

The shared iPhone semantic row now composes an explicit symbol and text. Text uses
the primary foreground at caption size, task types use compact product vocabulary,
and semantic color is limited to the symbol and outline over a neutral fill.
Accessibility labels identify whether each value is a task type or status, and
the existing adaptive layout stacks complete badges when needed.

## Prevention Rule

When a badge communicates task meaning, keep its complete wording readable without
depending on tint, symbol recognition, or an inherited `LabelStyle`. Use color and
icons to reinforce text, never to replace it.

## Regression Safeguard

`IOSHomeWorkspaceNavigationSourceTests.compactSemanticBadgesNameTaskTypeAndStatusWithoutDependingOnColor`
protects the explicit text composition, primary text contrast, semantic outline,
and task-type/status accessibility labels. The iOS workspace-control scenario
requires complete named badges in both Backlog and Task Ladder.

Related decision: [0738 — Label iOS Task-Row Badges Explicitly](../decisions/0738-label-ios-task-row-badges-explicitly.md).
