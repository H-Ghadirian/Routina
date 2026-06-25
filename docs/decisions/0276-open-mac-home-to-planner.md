# 0276 Open Mac Home to Planner

- Status: Accepted
- Date: 2026-06-25
- Refines: [0005 Show Timeline Activity in Day Planner](0005-show-timeline-activity-in-day-planner.md), [0021 Keep Mac Places in the Home Split Shell](0021-keep-mac-places-in-home-split-shell.md)

## Context

Planner is now a first-class Home surface for reviewing the day and week, dragging work into time, and seeing completed activity. Opening a fresh Mac Home window on Details can show an empty task-detail placeholder until the user selects a task, even though the Planner is the primary planning surface.

## Decision

Fresh Mac Home instances open with the Planner detail mode selected by default.

Details remains visible and selectable. Task, note, goal, event, sprint, sleep, Places, and focus deep links or actions can still switch the Home shell to the surface they need. The launch default is not a durable last-selected-screen preference.

## Consequences

- Opening the Mac app lands users directly on the Planner calendar.
- Users can still switch to Details manually or through task/detail actions.
- Deep links keep their explicit mode routing instead of inheriting the launch default.
