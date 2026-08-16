# 0583: Keep Task Creation Unlimited

## Status

Accepted

## Date

2026-08-16

## Supersedes

- [0290: Limit Free Active Tasks Behind Subscription](superseded/0290-limit-free-active-tasks-behind-subscription.md)
- [0293: Add Settings Unlimited Task Override While Products Are Unavailable](superseded/0293-add-settings-unlimited-task-override-while-products-unavailable.md)
- [0374: Move Unlimited Task Override to Beta Experiments](superseded/0374-move-unlimited-task-override-to-beta-experiments.md)

## Revises

- [0315: Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md)
- [0457: Confirm Successful Mac Task Creation](0457-confirm-successful-mac-task-creation.md)
- [0466: Harden App Store Release Surfaces](0466-harden-app-store-release-surfaces.md)
- [0487: Allow Archiving One-Off Tasks](0487-allow-archiving-one-off-tasks.md)

## Context

Routina previously allowed ten active tasks for free and required a StoreKit
subscription or lifetime purchase before another active task could be created.
That made a core capture action depend on task lifecycle counting, entitlement
resolution, product availability, and a paywall recovery flow.

Task capture should remain dependable as a person's responsibilities grow. A
person should not need to archive, complete, or purchase access merely to record
another legitimate task, and every creation entry point should have the same
rule.

## Decision

Task creation is unlimited for everyone on iOS and macOS. No task count,
subscription entitlement, lifetime purchase, build variant, or testing override
may block full Add Task, Smart Add, toolbar creation, or Quick Add.

The active-task usage gate and its StoreKit product catalog, purchase, restore,
entitlement, paywall, pending-save, and development-override flows are removed.
Routina does not currently offer an in-app purchase whose benefit is additional
task capacity.

The legacy synchronized `unlockUnlimitedTasks` preference and backup field remain
inert for persistence and backup compatibility. They are not exposed in Settings
and do not influence behavior. Removing that stored field requires a separate
data-model compatibility decision.

## Consequences

- A task save can fail for validation or persistence reasons, but never because
  the person already has too many tasks.
- Creation behavior is consistent across detailed and quick entry points on both
  platforms.
- The task-limit paywall, purchase copy, restore action, StoreKit task products,
  and development bypass control no longer appear in the app.
- Archiving and other lifecycle actions exist only to express the person's intent
  and manage visibility; they do not recover task capacity.
- Any future monetization model needs a new decision and must not reintroduce a
  task-count cap without explicitly superseding this decision.
