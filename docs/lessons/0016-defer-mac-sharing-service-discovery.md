# 0016 — Defer Mac sharing-service discovery until selection

Date: 2026-07-24

## Symptom

Opening the Link menu in Mac Task Details took a long time before its Share Link
and Copy Link actions appeared.

## Root Cause

The lightweight outer `Menu` embedded SwiftUI's `ShareLink`. On macOS,
constructing that nested system share control could discover available sharing
services while AppKit was opening the outer menu, delaying both of its actions.

## Fix

The Mac Link menu now contains a normal Share Link button. Selecting it closes
the lightweight menu first and then asks an `NSSharingServicePicker` to discover
and display the system sharing destinations. iOS retains its native `ShareLink`.

## Prevention Rule

Do not embed `ShareLink` directly inside a Mac menu that must open immediately.
Keep the menu actions lightweight and defer system sharing-service discovery
until the user selects the share action.

## Regression Safeguard

The macOS performance regression suite verifies that deep-link menus route Mac
sharing through the deferred AppKit presenter rather than nesting a Mac
`ShareLink`.
