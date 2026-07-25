# 0022 — Do not infer optional-section intent from legacy defaults

Date: 2026-07-25

## Symptom

Older tasks showed Priority in Task Details even though Priority was absent from Edit Task and the user had never added the section.

## Root Cause

Task Details inferred visibility from the stored `priority` value. Older creation paths persisted `.medium` for the neutral Medium/Medium matrix, so a legacy default was mistaken for explicit user intent.

## Fix

Priority disclosure now has a durable per-task visibility preference. Legacy Medium/Medium tasks remain hidden unless that preference is set, while non-neutral matrix values and High/Urgent priority values remain visible. Adding Priority in Task Details and explicit Quick Add priority syntax persist the preference.

## Prevention Rule

Do not use a historically overloaded default value as proof that a user deliberately revealed an optional section; persist disclosure intent separately and define a compatibility rule for legacy records.

## Regression Safeguard

Shared visibility tests cover legacy Medium/Medium, explicitly revealed Medium, and customized priority values. Reducer and Quick Add tests verify that deliberate reveals persist.
