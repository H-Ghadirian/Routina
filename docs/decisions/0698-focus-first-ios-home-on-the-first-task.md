# 0698: Focus First iOS Home on the First Task

## Status

Accepted

## Date

2026-08-30

## Revises

- [0539: Offer iOS Task Creation From Home Empty States](0539-offer-ios-task-creation-from-home-empty-states.md)
- [0664: Open iOS Workspaces From the Home List](0664-open-ios-workspaces-from-the-home-list.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0543: Defer iOS Sync Refresh Work Until Its Tab Is Active](0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md)

## Context

The normal empty iOS Home combined a task-creation card with Backlog, Timeline,
Task Ladder, task-type chrome, and Filters. Those destinations are useful after
someone has begun using Routina, including when an established task catalog is
later empty. On a genuinely new installation, however, they ask the person to
understand organization, history, and ranking before there is any work to
organize, review, or compare.

Routina needs to distinguish first use from an ordinary empty list. Task count
alone cannot make that distinction because an established person may delete,
archive, or temporarily synchronize away every task. An app update also must not
make an existing empty installation look new.

## Decision

After the initial Home task snapshot loads empty on a genuinely new iOS
installation, Home presents one focused first-task experience. It uses the
`Home` title, asks `What would you like to get done?`, explains that organization
and scheduling can come later, and offers one full-surface `Create Your First
Task` action that opens the existing Smart Add flow.

While this experience is pending, Home omits its task-type actions, Filters,
and the Backlog, Timeline, and Task Ladder rows. The standard bottom tabs remain
available, including Settings and New, so first-task guidance does not become a
blocking onboarding wizard. Home keeps its loading presentation until an
initial task snapshot exists rather than treating an unresolved local load as
an empty catalog.

Eligibility is installation-local. A new version seeds existing installations
as already complete by recognizing their established installation identifier.
Once this installation observes any task—created locally, imported, restored,
or synchronized—the first-task experience is permanently complete. Deleting all
tasks later restores the established `No tasks yet` state with Add New Task and
the three workspace rows; it never replays first-use guidance.

The dedicated Search tab keeps its normal search and no-results behavior. This
first-task presentation belongs only to Home.

## Consequences

- A new person sees one immediate outcome instead of empty advanced workspaces.
- Smart Add remains the single task-capture implementation; first use does not
  introduce another form or draft model.
- Existing installations, including empty ones, retain their familiar workspace
  navigation after updating.
- A task arriving through synchronization retires the prompt just like a locally
  created task.
- Installation-local completion is intentionally not a synchronized preference;
  each genuinely new device can orient itself until it observes the person's
  task catalog.
