# 0126 — Discover remotely started Focus during iOS reconciliation

Date: 2026-08-10

## Symptom

An active Focus timer started on macOS did not appear after opening Routina on iOS.

## Root Cause

The iOS direct CloudKit reconciliation returned before its initial pull whenever the local store had no active Focus record. That protected against stale local timers but could not discover a timer that began on another device.

## Fix

iOS now runs one coalesced, bounded Focus reconciliation at launch and whenever it becomes active. The first pull always runs; the existing short retry only runs if that pull finds an active Focus session.

## Prevention Rule

A cross-device reconciliation must first discover remote active state. Do not gate its initial pull on the receiving device already containing that state.

## Regression Safeguard

`CloudKitDirectPullFocusSessionTests.cloudKitReconciliation_discoversAnActiveFocusSessionFromAnotherDevice` verifies that a receiving store with no Focus session imports a remotely active one and performs the bounded retry. The cross-device scenario is recorded in `docs/scenarios/README.md`.
