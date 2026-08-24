# 0609 — Keep Planner range choices actionable in compact headers

Status: Accepted

The segmented-versus-menu presentation is revised by
[0654: Progressively reveal Mac Planner header choices](0654-progressively-reveal-mac-planner-header-choices.md).
Range eligibility, readable day widths, preferred-range restoration, and the
icon-only date fallback remain active.

The loaded Focus-control behavior is refined by [0614: Collapse the Planner date label when Focus is visible](0614-collapse-planner-date-label-when-focus-is-visible.md), which allows the date button to collapse independently of the other header choices.

Date: 2026-08-18

Revises the range-picker-hiding behavior in [0305: Hide Planner Range Picker When Header Cannot Fit](0305-hide-planner-range-picker-when-header-cannot-fit.md), [0307: Hide Planner Range Picker in Day Inspector Layout](0307-hide-planner-range-picker-in-day-inspector-layout.md), and [0320: Hide Planner Range Picker in Tight Inspector Layouts](0320-hide-planner-range-picker-in-tight-inspector-layouts.md). Refines [0303: Align Mac Planner Range Picker with Adaptive Days](0303-align-mac-planner-range-picker-with-adaptive-days.md) and [0606: Show Icon-Only Go to Date Button Before Label Truncation](0606-show-icon-only-go-to-date-button-before-label-truncation.md).

## Context

The Mac Planner decided whether its range picker fit from header width, but decided whether `Day`, `3 Days`, or `Week` could render from calendar width. That allowed the header to advertise `Week` while the calendar immediately constrained the selection back to `3 Days`. The calendar also used a stricter hard-coded range threshold than its renderer's actual minimum day width, leaving usable horizontal space unavailable.

Hiding the entire range picker in a tight header avoided crowding but removed the person's route for changing range. The Planner view and Calendar task-view segments could consume enough width that the date control retained text after the header was already visually compact.

## Decision

Planner range eligibility and rendered day-column sizing use the same readable 96-point minimum day width after reserving the time column. The range control lists only modes that can take effect at the current calendar width. A temporarily unavailable preferred range remains stored and can return when space becomes available, but it is not advertised as an actionable current choice.

On macOS, the header presents Planner view, Calendar task view, and Planner range as segmented controls only while the Calendar header is at least 1520 points wide, the full regular row fits with a 120-point usability reserve, and every range is available. Otherwise, each becomes a native current-value menu, following the Task Ladder's compact choice pattern. The range menu remains available instead of being hidden and contains only currently supported ranges.

The same compact-header decision makes `Go to date` icon-only. Its accessible label, selected date or range value, hint, help, and full button hit area remain available.

## Consequences

- Every visible range choice takes effect when selected.
- Week and 3 Days fit at narrower widths without rendering columns below the shared readable minimum.
- Tight headers retain all view and range choices without carrying three expanded segmented controls.
- The preferred range can restore after resizing, while the effective visible range and current control remain truthful.
- Header and calendar width still have distinct responsibilities, but the header consumes the calendar's supported-range result instead of independently advertising all modes.
