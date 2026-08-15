# Contextual Task Ladder Product Exploration

## Status

Mixed product exploration. Independent Task Ladder placement and container-only
groups are implemented by the accepted decision below. Temporary focus,
cross-group finalists, available-time filtering, and `What should I do now?`
remain proposals and do not describe current behavior.

Implemented foundation:

- [Decision 0574: Separate Task Ladder Placement From Completion](decisions/0574-separate-task-ladder-placement-from-completion.md)
- [Current task behavior](current-behavior/tasks.md)

## Product Problem

A flat ladder asks a person to compare tasks that may not be meaningful peers.
`Call Mom` and `Check the tracking ticket in Amplitude` can both matter without
benefiting from repeated direct comparison. At the same time, completely
isolating work into separate ladders makes it harder to answer the final question:
`What should I do now?`

The desired product model separates three decisions:

1. **What commitment or life area deserves attention now?**
2. **What is the best actionable task inside that commitment or area?**
3. **When several areas have valid candidates, which finalist should win now?**

The product should reduce the number of comparisons without hiding urgent
cross-area exceptions or requiring an opaque priority formula.

## Distinct Concepts

### Completable parent with placed tasks

An actionable parent represents the commitment that participates in the general
ladder. Its children are placed inside it for comparison. Each child's separate
completion rule determines whether it does nothing to the parent, may fulfill
the parent after confirmation, or fulfills the parent automatically.

Example: `Exercise` with `Walk`, `Gym`, `Swim`, `Running`, and `Hiking`.

Independent placement is implemented by Decision 0574. The person's choice of
`Can complete` retains the manual fulfillment behavior from Decision 0409.

### Container-only group

A Task Ladder group organizes separate obligations that may all still need to be
completed. The group itself is not a fake completable task.

Example: `Company` containing an Amplitude tracking ticket, a customer report,
and an experiment review. Completing one ticket does not complete Company.

Container-only groups and one-parent task placement are implemented by Decision
0574. Groups remain Task Ladder-specific and do not reuse Home Paths.

### Temporary group focus

The relative attention given to Company, Family, and Travel changes by day or
period. A temporary focus order should express that allocation without rewriting
the Importance or Urgency of every contained task.

Example:

```text
Focus today

1. Company     Primary until Friday
2. Family
3. Travel
```

Tomorrow, Family may become primary. Before a trip, Travel may be primary until
a selected date. Expired focus should not silently remain authoritative.

### Next-action frontier

Routina does not need to compare every leaf task globally to find the next useful
choice. It can compare the best currently actionable candidate from each relevant
Group or commitment.

If Company is ordered `A > B > C`, Family is `F > G`, and Travel is `T`, the
global finalists are `A`, `F`, and `T`. `B` and `C` do not need global comparison
while `A` remains the preferred Company task. After a finalist is completed or
becomes unavailable, that source contributes its next candidate.

This is a bounded global comparison, not a permanent total order over every task.

## Refined Examples

### Exercise: choose the commitment, then choose how

The parent routine has Medium Importance, Low Urgency, and no single fixed
duration. The root ladder shows one row:

```text
Medium importance · Low urgency

🏃 Exercise
   Flexible duration · 5 tasks                           ›
```

Opening it presents only actionable placed tasks:

```text
‹ Task Ladder    Exercise

Available time:  Any   15m   30m   60m+

Walk        20 min
Running     30 min
Gym         60 min
Swim        75 min
Hiking      3 hours
```

The root decision is whether Exercise deserves attention. The nested decision is
how to exercise given preference, time, and availability. Child durations are
factual and should not be summed into a parent estimate. A future UI may present
the parent as `Flexible · 20 min–3 hours` or retain `No estimate`; that choice
needs a separate decision.

Completing Walk may explicitly fulfill today's Exercise occurrence. History
should retain both facts without double-counting aggregate completion:
`Exercise completed — Walk`.

### Company: organize obligations without inventing a task

The root view may show one navigable Company row rather than every work ticket:

```text
🏢 Company
   18 actionable tasks                                  ›
```

Opening Company presents its task ladder. Unlike Exercise, the children are not
alternatives and completing one does not satisfy the container. Company should
therefore be visibly identified as a Group, not as a repeating task.

### Company, Family, and Travel: focus changes over time

Group focus is temporary attention allocation. It must not cascade values into
children. Making Family primary today does not lower the saved Importance of an
Amplitude ticket, and making Company primary does not make every Company task
more urgent than every Family task.

### What should I do now?

The root can show a small explainable finalist set:

```text
What should I do now?

🏠 Call Mom
   Due today · 10 min

🏢 Fix Amplitude tracking
   First in Company · Company is primary today · 25 min

✈️ Book hotel
   Deadline tomorrow · 20 min
```

Routina may recommend one candidate, but it should also show the alternatives and
a concise reason. `Call Mom` can outrank the primary Company candidate because a
hard deadline is an explicit exception. The product should not expose a false-
precision numeric score.

## Proposed UI and Interaction Principles

- Root rows must distinguish actionable tasks, completable task parents, and
  non-completable Groups through labels, icons, and completion affordances.
- A row with nested content opens that ladder across its full intended hit area.
  Task Details remains available through an explicit action or adjacent detail
  presentation.
- Nested ladders retain a visible breadcrumb/back path and the person's local
  metric, direction, disclosure, and selection context where practical.
- Root counts and nested counts describe actionable rows. Unavailable children
  should not disappear without explanation when the parent is opened.
- `All Tasks` remains available as an audit and recovery view, but need not be the
  default daily decision surface.
- Search results for nested items show their path, such as
  `Exercise › Swim` or `Company › Fix Amplitude tracking`, and navigate to the
  matching scope.
- Temporary focus has an explicit duration such as Today, This week, or Until a
  date. The UI makes expiration visible.
- A lower-focus Group can still contribute a finalist when it contains a scheduled,
  due, overdue, in-progress, or otherwise explicitly time-constrained task.
- Context such as available time filters or reorders candidates transparently.
  Longer options remain discoverable under a clear `Doesn't fit` state rather
  than silently disappearing.
- Physical effort must not be inferred from `Thinking needed`, which describes
  cognitive demand. A generic Energy/Effort model would need its own decision.
- Initial hierarchy depth should remain shallow. Arbitrary recursive nesting
  would increase navigation, cycle, search, sync, and explanation complexity.

## Business and Product Consequences

- Routina moves from being only a task catalog toward being an explainable
  decision system: choose an area or commitment, then choose its next action.
- The product value is reduced cognitive load, not automatic judgment. People
  retain control over Group focus, task order, and final selection.
- Onboarding must teach that a Group is container-only while a task parent can
  have nested work with an independent completion rule.
- The superseded completion-option relationship was never shipped or used, so it
  is removed without migration. Existing `Can complete` and `Completes` rules
  retain their established fulfillment meanings and never imply placement.
- The feature must remain useful with partial organization. The general/root
  ladder prevents mandatory setup before Task Ladder provides value.
- Candidate derivation must reuse cached immutable presentations. Group expansion,
  global finalists, and context changes cannot introduce whole-history work into
  scrolling render paths.
- Sync and backup must preserve Group identity, temporary focus expiration,
  membership, and scope-specific ranks before the feature can be considered
  durable.
- Product validation should focus on whether people reach a confident next action
  with fewer comparisons and can explain why it was suggested. Routina currently
  does not use product Analytics, so any telemetry proposal requires a separate
  privacy decision; structured usability studies and direct feedback are the
  default validation path.

## Product Scenarios

The placement, completion, and deletion scenarios below are accepted current
behavior. Temporary focus, finalists, available-time context, and hierarchy-aware
search remain inputs for later decisions.

### Completion alternatives stay local

Given Exercise participates in the root ladder
And Walk, Gym, Swim, Running, and Hiking are placed inside it
When the root ladder is shown
Then Exercise appears once
And its placed tasks appear only after opening Exercise
And a selected task's independent `Can complete` rule can explicitly fulfill
Exercise once.

### Containers do not inherit completion semantics

Given Company is a Group containing several tickets
When one ticket is completed
Then the ticket leaves or advances according to its own lifecycle
And Company remains available while other actionable work exists
And no Company completion is recorded.

### Temporary focus changes without metadata cascades

Given Company is primary today
When Family is made primary tomorrow
Then the Group order changes for tomorrow
And task-level Importance, Urgency, Pressure, estimates, and history do not change.

### Global finalists remain bounded

Given several Groups each have locally ordered tasks
When Routina builds the `What should I do now?` view
Then it shows only the best eligible candidate from each relevant Group
And it does not compare or render every lower-ranked task globally.

### Explicit constraints can override focus

Given Company is the primary Group
And Call Mom in Family is due today
When Routina recommends a next action
Then Call Mom remains a visible finalist
And any recommendation explains the deadline exception.

### Unavailable leaders yield to the next candidate

Given the first Company task is blocked, paused, unavailable by date, or excluded
When the finalist set is rebuilt
Then Company contributes its next actionable task
And the unavailable task does not silently become the recommendation.

### Available time narrows implementation choices

Given Exercise has options from 20 minutes to three hours
When the person says they have 30 minutes
Then Walk and Running remain primary choices
And longer options remain discoverable as not fitting the current time.

### Search preserves hierarchy

Given Swim is nested under Exercise
When global search finds Swim
Then the result identifies `Exercise › Swim`
And opening it restores that nested ladder rather than flattening Swim into the
root comparison.

### Deleting organization never deletes work

Given a Group is deleted
When it still owns tasks
Then those tasks return to the general/root ladder
And their task data, history, relationships, and non-Group metadata remain intact.

### Placement and multiple fulfillment targets stay independent

Given one task can fulfill more than one commitment
And it has one Task Ladder placement
When the task is ranked
Then it has only the placed parent's local tie-break order
And completing it asks which eligible commitments to fulfill.

## Staged Decision Boundaries

1. **Implemented:** independent placement, container-only Groups, root
   suppression, nested Mac ladders, scope-specific tie-break ranks, and separate
   none/manual/automatic completion rules.
2. **Later decision:** temporary Group focus, expiration, persistence, sync, and
   whether focus applies per device or across devices.
3. **Later decision:** the bounded `What should I do now?` finalist surface,
   explainable exception precedence, and available-time context.
4. **Later decision:** iOS presentation and parity after the product semantics are
   validated on the Mac Task Ladder.

## Open Questions

- Should Groups eventually nest inside other Groups, or is a root Group plus
  nested task hierarchy enough?
- Should Group focus be a temporary ordering layer independent from saved
  Pressure, Importance, Urgency, and Thinking needed values?
- Which conditions are hard exceptions in `What should I do now?`: scheduled now,
  due today, overdue, in progress, blocking other tasks, or user pinning?
- Should the recommendation choose one finalist automatically or present a small
  shortlist by default?
- How should flexible parent duration appear in Estimated time without summing
  mutually exclusive options or claiming one duration is authoritative?
- Should direct completion of a parent with options ask which option occurred,
  allow an unlisted method, or remain a normal completion with optional detail?
- How much hierarchy is enough before a flat search/breadcrumb becomes safer than
  deeper nested ladders?
