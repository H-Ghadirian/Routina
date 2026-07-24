# 0010 — Keep Mac Sidebar Context-Menu Tracking Out of SwiftUI

Date: 2026-07-24

## Symptom

A populated custom-section context menu opened, but moving through its actions
was extremely laggy. The app consumed a full CPU core until menu tracking
finished.

## Root Cause

SwiftUI owned the section and group context menus. While AppKit tracked the
menu, SwiftUI continuously flushed the host view graph, repeatedly traversing
`ForEach` content and laying out the Liquid Glass-heavy task sidebar.

The earlier empty-menu defect documented in
[0009](0009-never-install-empty-mac-context-menus.md) exposed the same framework
boundary more severely, but gating empty menus did not isolate populated menus
from the sidebar render graph.

## Fix

Section and group headers now use Routina's AppKit-backed `NSMenu` bridge, which
was already used by task rows. Custom-section management, Future expansion, and
optional focus-timer actions are built as native menu items and tracked outside
SwiftUI's menu transaction.

## Prevention Rule

Use the AppKit context-menu bridge for macOS menus attached to large, dynamic,
or Liquid Glass-heavy SwiftUI surfaces. SwiftUI context-menu tracking must not
own an unbounded sidebar render graph.

## Regression Safeguard

The macOS performance regression suite verifies that section and group headers
build native menus through `routinaMacContextMenu` and do not call the former
SwiftUI section-menu builder.
