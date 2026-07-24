# 0020 — Put hit shapes inside control labels

Date: 2026-07-25

## Symptom

The Link control in Mac Task Details displayed a full rounded button surface,
but only the link and chevron icons opened its menu.

## Root Cause

The shared task-detail toolbar applied its fixed frame, background, and
`contentShape` outside the SwiftUI `Menu`. The menu's own label retained its
intrinsic icon-only size, so the larger decorative wrapper did not enlarge the
menu control's interactive label.

## Fix

The plain-toolbar Link menu label now expands to the full size proposed by its
surrounding toolbar chrome and defines that expanded rectangle as its content
shape.

## Prevention Rule

For custom SwiftUI buttons and menus, make the control's label fill the intended
visual surface and put its hit shape inside that label. A decorative wrapper
outside the control does not reliably enlarge the control's hit target.

## Regression Safeguard

The macOS performance regression suite verifies that the plain-toolbar
deep-link menu label fills its proposed width and height and defines an explicit
full-label content shape.
