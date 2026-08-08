# 0111 — Gate the Mac sleep command by the Away setting

Date: 2026-08-08

## Symptom

The macOS application menu still showed `Going to Sleep` after the user turned off `Show Away` in Settings.

## Root Cause

`RoutineCommands` registered the sleep command unconditionally, bypassing the existing `isAwayEnabled` gate used by the rest of the macOS Away and Sleep surfaces.

## Fix

The application-menu sleep command now appears only while `Show Away` is enabled.

## Prevention Rule

Every macOS command that exposes an experimental or hidden surface must use the same persisted availability setting as the in-app entry points.

## Regression Safeguard

`MacSleepMenuAvailabilityTests.applicationMenuHidesSleepWhenAwayIsDisabled` verifies that `Going to Sleep` remains nested inside the `isAwayEnabled` gate.
