# 0106 Support Unassigned Watch Focus Sessions

- Status: Accepted
- Date: 2026-05-30

## Context

Apple Watch is the lowest-friction place to start a focus timer, but choosing a task or board on the watch adds work at the moment the user wants to begin. Routina already treats task focus and board sprint focus as accountable time, and watch-originated actions should preserve Apple Watch as the source device when iPhone relays them.

## Decision

Apple Watch can start a count-up focus timer without choosing a task or board. The iPhone relay creates a normal `FocusSession` using a stable `FocusSession.unassignedTaskID` sentinel instead of creating a hidden task or adding optional task relationships to existing focus history.

Unassigned focus sessions stay unassigned while active and completed. They do not create planner blocks. iPhone and Mac Stats surface completed unassigned focus sessions so the user can later assign the time to a task, or convert it into board focus history for an active board sprint.

Task assignment updates the existing focus history row to the chosen task. Board assignment creates a `SprintFocusSessionRecord` with the same timing and removes the unassigned `FocusSession`, because board focus history has its own model.

## Consequences

- Starting focus from Apple Watch stays one-tap and does not require task or board selection.
- Aggregate focus stats can include unassigned focus time before it has been attributed.
- Existing `FocusSession.taskID` storage remains non-optional, avoiding a broad SwiftData migration for this workflow.
- Cleanup that deletes orphaned task timeline rows must preserve the sentinel unassigned focus sessions.
- Planner blocks remain tied to task-start intent and are not retroactively created from unassigned focus attribution.
