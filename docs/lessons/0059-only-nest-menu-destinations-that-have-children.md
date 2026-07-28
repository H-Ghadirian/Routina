# 0059 — Only nest menu destinations that have children

Date: 2026-07-28

## Symptom

Every custom super section in a Mac task row's `Move to` menu showed a chevron, including sections with no subsections. Selecting one of those leaf sections opened a redundant one-item submenu.

## Root Cause

The native AppKit menu builder unconditionally wrapped every super section in an `NSMenu`, while the SwiftUI Add/Edit task path picker already distinguished leaf sections from sections that contain children.

## Fix

The native `Move to` builder now adds a leaf super section as a direct action and creates a nested submenu only when the super section has subsections.

## Prevention Rule

When presenting the same hierarchy through multiple menu implementations, derive disclosure from actual child cardinality at every surface: leaf nodes are commands, and only nodes with children are submenus.

## Regression Safeguard

`HomeFeatureTests.macMoveToMenuOnlyNestsSuperSectionsWithSubsections` constructs both shapes and verifies that the leaf has an action without a submenu while the parent retains its direct-parent and subsection destinations.
