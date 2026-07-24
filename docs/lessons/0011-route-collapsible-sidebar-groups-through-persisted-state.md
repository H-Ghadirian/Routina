# 0011 — Route every collapsible sidebar group through persisted state

Date: 2026-07-24

## Symptom

User-created subsections in the Mac task sidebar displayed an expansion chevron but could not be collapsed, and their header looked unlike built-in tag subsections.

## Root Cause

The shared presentation model correctly marked custom subsection groups as collapsible, but the Mac view's kind-specific expansion switches treated `.custom` groups as always expanded. Its section-surface predicate also omitted `.custom`, so the same group fell back to the lightweight nested label.

## Fix

Custom subsection groups now read and write the shared persisted group-collapse ID set, participate in programmatic reveal, and use the same nested card header surface as built-in tag groups.

## Prevention Rule

When a presentation group sets `isCollapsible`, every view-level expansion, toggle, reveal, and styling dispatch must explicitly support that group kind; do not pair a visible disclosure affordance with an always-expanded fallback.

## Regression Safeguard

The Mac sidebar regression test checks that custom groups use the section surface and are included in both live and snapshot-based persisted collapse handling. The task-list scenario also records the expected visual and interaction parity.
