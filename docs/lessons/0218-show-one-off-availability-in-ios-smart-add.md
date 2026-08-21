# 0218 — Show one-off availability in iOS Smart Add

Date: 2026-08-21

## Symptom

Entering `Physiotherapist Tuesday, 25 August 15:00` in iOS Smart Add appeared not to be recognized because no Detected section was shown.

## Root Cause

The shared parser produced a valid one-off availability draft, but the iOS presentation only added a schedule row for repeating drafts or explicit deadlines. A one-off availability with no deadline therefore produced no detail rows, and the whole Detected section was hidden.

## Fix

iOS Smart Add now presents one-off date/time availability as an `Available` detected row using the parsed date and time.

## Prevention Rule

Every supported schedule meaning must have a visible confirmation row on each Smart Add surface, including one-off availability that is not a deadline.

## Regression Safeguard

`Tests/iOS/IOSSmartAddDetectedChipsTests.swift` parses the reported input and verifies that iOS exposes an `Available` row with the exact event time.
