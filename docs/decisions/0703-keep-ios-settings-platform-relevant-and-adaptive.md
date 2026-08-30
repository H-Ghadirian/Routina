# 0703: Keep iOS Settings Platform-Relevant and Adaptive

## Status

Accepted

## Date

2026-08-30

## Revises

- [0006: Make Planner Timeline Activity Configurable](0006-make-planner-timeline-activity-configurable.md)
- [0637: Search Settings by Destination](0637-search-settings-by-destination.md)
- [0674: Hide Flagged Tasks From Calendar List](0674-hide-flagged-tasks-from-calendar-list.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0279: Hide Sleep Stats and Blocking With Away Toggle](0279-hide-sleep-stats-and-blocking-with-away-toggle.md)
- [0698: Focus First iOS Home on the First Task](0698-focus-first-ios-home-on-the-first-task.md)

## Context

iOS Settings exposed controls whose result could be observed only on Mac,
including Planner timeline placement and Hide from Calendar List. Its search
catalog and summary copy also advertised Planner, Calendar List, and keyboard
concepts that had no iOS destination. Some controls were technically valid but
inert during the focused first-task experience or while their parent feature
was unavailable.

Cross-device configuration is not enough reason to present a control as an iOS
feature. At the same time, hiding a Mac-only behavior on iOS must not destroy a
synced assignment when the task is edited on the phone or tablet.

## Decision

iOS Settings presents only controls whose result is observable or actionable on
iOS. Planner Calendar configuration remains in Mac Settings and is omitted from
iOS Calendar. Settings search terms, result explanations, row summaries, and
Shortcuts icon/copy follow the current platform rather than sharing Mac labels.

The canonical persisted Flag catalog remains five values for sync, backup, and
Mac behavior. Mac exposes all five. iOS omits Hide from Calendar List from
Settings, Add/Edit Task, Task Details, Home, Timeline, and Stats filter
presentation. A Mac-originated assignment remains in the task draft and is
saved unchanged by iOS; only its presentation and iOS filter eligibility are
removed.

iOS Settings uses the installation-local first-task completion marker already
owned by Home. Before the first task has been observed, General omits the Home
task-type control and Shortcuts omits Mark Done. Once any task is created,
imported, restored, or synchronized, those controls remain available even if
the task catalog later becomes empty.

Sleep shortcut controls appear only while both Away and Sleep are enabled.
The charge-task battery threshold appears only while charge repeating tasks are
enabled. Controls that can create the first task, configure global behavior,
preview their result, or provide recovery remain available on an empty catalog.

## Consequences

- iPhone and iPad no longer suggest that they contain a Planner Calendar,
  Calendar List, or Mac keyboard-shortcut surface.
- Mac keeps its Planner Calendar preference and complete Flag catalog.
- iOS task edits cannot accidentally erase an invisible Mac-only assignment.
- A genuinely new installation sees fewer advanced task controls, while an
  established installation retains them during a later empty catalog.
- Settings search explains only controls that the selected platform can open.
- Future Settings controls must declare both platform relevance and any data or
  feature prerequisite at their presentation boundary.
