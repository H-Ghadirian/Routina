# 0507: Clarify iOS Task Detail Action Hierarchy

Status: Accepted

Date: 2026-08-08

Refines: [0188 Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0421 Support Cadence-Free Repeating Routines](0421-support-cadence-free-repeating-routines.md), and [0424 Make Task Detail Priority Optional](0424-make-task-detail-priority-optional.md)

## Context

iOS Task Detail mixed the main completion action with routine maintenance actions. Its compact Priority summary could place the overall value and the importance/urgency dimensions on awkward competing lines, and Pressure appeared alongside completion controls instead of with task metadata. Cadence-free routines also remained intentionally repeatable after completion, but the unchanged `Done` label made that behavior look accidental.

## Decision

On iOS Task Details:

- Priority presents its label and overall value on the first line, with Importance and Urgency together below it.
- Pressure stays in the header metadata, rather than in the primary action card.
- Completion is the only prominent action. Pause/Resume and Not today are nested in a subdued `More routine actions` menu. The latter is explicitly named `Not today — hide until tomorrow`.
- A cadence-free routine remains immediately available and preserves every completion as required by Decision 0421. Once it has a completion for today, iOS changes the primary label to `Log another completion` and adds a plus symbol; it does not present the action as an ordinary first-time completion.

## Consequences

- Routine maintenance actions remain available without competing with the expected everyday completion path.
- The screen identifies task metadata by location and action intent by prominence instead of relying on detached helper copy.
- People can keep recording multiple same-day cadence-free completions, while the affordance makes that exceptional follow-up action explicit.
