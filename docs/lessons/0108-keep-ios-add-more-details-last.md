# 0108 — Keep iOS Add More Details Last

Date: 2026-08-08

## Symptom

The iOS `Add more details` section appeared before Linked Tasks and other contextual Task Detail sections, making the disclosure look like it ended the screen before more task content followed.

## Root Cause

Both iOS Task Detail stacks inserted the generic optional-actions disclosure immediately after the primary controls instead of after their conditional content sections.

## Fix

The todo and routine stacks now place `Add more details` after all currently visible detail content.

## Prevention Rule

Keep generic progressive-disclosure entry points at the end of a detail surface; insert new task-context sections before them unless the section belongs to the disclosure itself.

## Regression Safeguard

`TaskDetailPlatformActionParityTests.iosAddMoreDetailsSectionIsLastForTodosAndRoutines` asserts the iOS todo and routine source layouts keep their task extras before the optional-actions section.
