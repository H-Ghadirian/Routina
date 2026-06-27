# 0290 Limit Free Active Tasks Behind Subscription

Status: Accepted

Date: 2026-06-27

## Context

Routina needs a freemium model that lets new users try the app without making task creation unlimited. The product offer is free usage up to a small active-task set, with weekly, monthly, annual, and lifetime paid options for people who want to keep adding work.

Task history and existing user data should not be deleted or mutated by monetization. The limit should apply only when creating a new active task, and it should use the same lifecycle language as the rest of the app: done or canceled todos and archived routines are not active work.

## Decision

Free Routina allows up to 10 active tasks. Creating another active task requires an unlimited-task entitlement.

Active-task counting includes todos and routines that are not paused, snoozed, archived, done, or canceled. Existing users who already have more than 10 active tasks keep their data, but cannot create another active task without unlocking unlimited tasks.

Unlimited tasks are unlocked by StoreKit entitlements. Weekly, monthly, and annual plans are renewable subscriptions; lifetime is a one-time entitlement. Product IDs are centralized in the subscription catalog and can be overridden from app configuration.

## Consequences

- All task creation entry points should route through the shared active-task gate before inserting a new `RoutineTask`.
- The paywall should preserve the user's pending detailed task save and retry it after a successful purchase or restore.
- Backup, import, CloudKit sync, and existing task lifecycle actions remain data-preserving and do not trim existing active tasks.
- Future paid features should extend the entitlement model instead of hard-coding StoreKit checks in views.

