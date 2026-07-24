# 0013 — Do not expose fallback recurrence for cadence-free tasks

Date: 2026-07-24

## Symptom

A repeating routine with `Repeat type: None` showed `Every day` in Task Detail and could receive a cadence-derived notification.

## Root Cause

Cadence-free tasks retain a normalized daily recurrence rule as inert storage fallback data. Presentation and notification eligibility read that fallback rule without first checking the persisted cadence-enabled flag.

## Fix

Task Detail and Home metadata now identify cadence-free tasks before formatting recurrence data, and notification eligibility rejects cadence-free tasks.

## Prevention Rule

Any code that interprets recurrence data must first establish that cadence is enabled. Never treat normalized fallback recurrence fields as an effective schedule.

## Regression Safeguard

`TaskDetailSharedViewSupportTests` verifies the frequency value is `None`, and `NotificationCoordinatorTests` verifies no notification is scheduled for a cadence-free routine. The cadence-free regression scenario lists both tests.
