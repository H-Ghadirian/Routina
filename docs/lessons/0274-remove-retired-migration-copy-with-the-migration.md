# 0274 — Remove retired migration copy with the migration

Date: 2026-08-30

## Symptom

Settings told people that configurable Flags would be migrated even though the
model never shipped to users and the migration implementation had already been
removed.

## Root Cause

The retirement focused on data conversion and startup behavior, while the
explanatory iOS and macOS Settings sections were left behind as if they still
described active behavior.

## Fix

Both Settings implementations now omit the legacy `About Flags` migration
section. Current documentation states that Flags use only the built-in model.

## Prevention Rule

When a pre-release migration is retired, remove its actions, markers, copy,
documentation, and tests together. Do not explain compatibility work that the
app neither needs nor performs.

## Regression Safeguard

`SettingsFlagRulePresentationTests` checks both platform sources for the current
built-in catalog and rejects migration headings or language.

Related decision: [0701 — Retire Pre-Release Flag Migration Guidance](../decisions/0701-retire-pre-release-flag-migration-guidance.md).
