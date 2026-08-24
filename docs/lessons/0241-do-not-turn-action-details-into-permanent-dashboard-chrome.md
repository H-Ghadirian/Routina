# 0241 — Do not turn action details into permanent dashboard chrome

Date: 2026-08-24

## Symptom

Expanded Mac Task Detail Effort showed two full duration editors, timer mode,
three Focus metrics, an accumulated-block grid, and history at once. The card
became tall and sparse, repeated values, and placed session edit actions far
from their rows on wide windows. Its collapsed summary could omit the recorded
Focus total entirely.

## Root Cause

The first independence fix mapped every underlying input and derived metric
directly onto the persistent detail surface. Correct state ownership did not
produce a clear information hierarchy: preparation controls, current values,
analytics, and history all competed at the same level.

## Fix

Effort now keeps populated values and direct actions in compact rows. Actual-time
entry and Focus setup open focused popovers only when requested. Embedded Focus
history uses a bounded recent list without repeated metric tiles or the block
grid, and its row actions remain near their sessions. Focus history also keeps
the Focus capability visible after first use.

## Prevention Rule

Keep stable detail surfaces focused on current values and next actions. Put
temporary preparation controls in a focused editor, and do not repeat one
derived fact across summary tiles, visualizations, and list headings unless each
representation answers a distinct user question.

## Regression Safeguard

`TaskDetailSharedViewSupportTests` protects the compact popover entry points,
independent state, retained Focus visibility, locked used-Focus presentation,
and embedded compact-history route.

See [Decision 0657](../decisions/0657-make-mac-task-detail-effort-a-compact-summary-and-action-surface.md)
and [Regression Scenarios](../scenarios/README.md#mac-task-detail-effort-stays-compact-and-reports-focus-history).
