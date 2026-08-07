# 0091 — Refresh Home after flag-rule changes

Date: 2026-08-07

## Symptom

After adding the `Hide tasks from normal task lists` rule to a flag already assigned to a task, the task remained visible in Home until a later refresh.

## Root Cause

Settings persisted the changed flag rules, but each app root only copied those rules into Home during its initial task load or a cloud-settings update. A direct local Settings action left Home filtering with the stale rule snapshot.

## Fix

Both app roots now reload sanitized flag rules into Home immediately after adding or removing a flag rule, and after removing a flag (which also removes that flag's rules).

## Prevention Rule

When a Settings-owned value affects a visible feature's filtering or presentation state, propagate direct local Settings mutations to that feature immediately; do not rely only on cloud or relaunch refreshes.

## Regression Safeguard

The iOS and macOS `AppFeatureTests.flagRuleChangesImmediatelyUpdateHomeFilteringRules` tests verify that adding and removing the rule updates Home's filtering rules in the same action.
