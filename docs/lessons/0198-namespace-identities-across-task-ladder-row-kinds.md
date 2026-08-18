# 0198 — Namespace identities across Task Ladder row kinds

Date: 2026-08-18

## Symptom

Accepting a linked-task suggestion correctly moved the task into its Task
Ladder value section, but the moved row could retain the suggestion's Accept
and Reject buttons. Those stale buttons no longer performed an action.

## Root Cause

The suggestion row used the linked task's UUID as its SwiftUI identity, which
was also the identity of the ordinary task row created after acceptance. The
rows live in the same lazy scrolling container, so SwiftUI could reuse the old
suggestion view when the task moved between row kinds instead of constructing
the ordinary Ladder row.

## Fix

Linked-task suggestions now use a parent/task suggestion identity type rather
than the task row's UUID. Accepting changes both section membership and semantic
row identity, forcing the lazy stack to replace the controls with the ordinary
Ladder presentation.

## Prevention Rule

When one domain object can move between semantically different row kinds in a
shared lazy container, namespace each row kind's identity. Do not reuse the
domain object's bare ID across views with different controls or behavior.

## Regression Safeguard

`TaskRankingPresentationTests.linkedTaskSuggestionIdentityIsDistinctFromItsAcceptedTaskRowIdentity`
asserts that a suggestion identity cannot collide with its task row identity.
The Task Ladder relationship scenario also requires acceptance to replace the
suggestion row without stale controls.
