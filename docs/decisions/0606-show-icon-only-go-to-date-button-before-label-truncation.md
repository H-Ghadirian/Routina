# 0606 — Show icon-only Go to date button before label truncation

Status: Accepted

The independent range-hiding fallback is revised by [0609: Keep Planner Range Choices Actionable in Compact Headers](0609-keep-planner-range-choices-actionable-in-compact-headers.md), which makes all header choices compact together and keeps the range menu available.

Date: 2026-08-18

Refines: [0292: Unify Planner Header Date Control](0292-unify-planner-header-date-control.md), [0305: Hide Planner Range Picker When Header Cannot Fit](0305-hide-planner-range-picker-when-header-cannot-fit.md), and [0320: Hide Planner Range Picker in Tight Inspector Layouts](0320-hide-planner-range-picker-in-tight-inspector-layouts.md)

## Context

The macOS Planner keeps `Go to date` available in the header so date navigation remains reachable in Calendar and Timeline. At narrow widths, the regular date label could be constrained into an ellipsis even though the button itself still had a clear icon-only alternative.

## Decision

The macOS Planner measures both the active header row with the intrinsic date label and the same full row with the compact calendar icon. The range picker may remain visible when the compact row fits; if that active row would overflow with the intrinsic label, `Go to date` switches to the icon-only button. If even the compact full row cannot fit, the range picker hides and date-label fit is recomputed against the collapsed row. The regular label does not scale or ellipsize. The button keeps its accessible label, selected date/range value, help text, and full click target. In companion-pane layouts, Calendar/Timeline text may collapse first.

## Consequences

- Date navigation remains available without displaying misleading or hard-to-read ellipsized date text.
- The selected date or range remains available through VoiceOver/accessibility value and help text.
- The change is presentation-only; date selection, Planner range state, and sidebar behavior are unchanged.
