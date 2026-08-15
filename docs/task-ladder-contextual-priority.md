# Contextual Task Ladder Product Exploration

## Status

Future product exploration. This document is not an accepted decision and does
not describe current behavior. Any section beyond the implemented completion-
option foundation requires a later numbered decision before implementation.

Implemented foundation:

- [Decision 0572: Nest Completion Options in the Mac Task Ladder](decisions/0572-nest-completion-options-in-mac-task-ladder.md)
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

### Commitment with completion options

An actionable parent represents the commitment that participates in the general
ladder. Its children are alternative ways to satisfy it. One suitable option may
fulfill the parent occurrence.

Example: `Exercise` with `Walk`, `Gym`, `Swim`, `Running`, and `Hiking`.

This concept is implemented by Decision 0572.

### Area or container

An Area organizes separate obligations that may all still need to be completed.
The Area itself is not a fake completable task.

Example: `Company` containing an Amplitude tracking ticket, a customer report,
and an experiment review. Completing one ticket does not complete Company.

Areas are not implemented by Decision 0572. They require a later decision about
ownership, persistence, interaction with Home Paths, and whether one task can
belong to more than one Area.

### Temporary Area focus

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
Area or commitment.

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
   Flexible duration · 5 options                         ›
```

Opening it presents only actionable completion options:

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
therefore be visibly identified as an Area, not as a repeating task.

### Company, Family, and Travel: focus changes over time

Area focus is temporary attention allocation. It must not cascade values into
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

- Root rows must distinguish actionable tasks, completion-option parents, and
  non-completable Areas through labels, icons, and completion affordances.
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
- A lower-focus Area can still contribute a finalist when it contains a scheduled,
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
  retain control over Area focus, task order, and final selection.
- Onboarding must teach the difference between an Area, a completable parent,
  and a completion option. Reusing one generic `Group` term would obscure
  different completion behavior.
- Existing tasks and relationships must not be auto-converted. Migration guesses
  could hide standalone work or create false fulfillment behavior.
- The feature must remain useful with partial organization. An `Unsorted` or
  root-task path prevents mandatory setup before Task Ladder provides value.
- Candidate derivation must reuse cached immutable presentations. Area expansion,
  global finalists, and context changes cannot introduce whole-history work into
  scrolling render paths.
- Sync and backup must preserve Area identity, temporary focus expiration,
  membership, and scope-specific ranks before the feature can be considered
  durable.
- Product validation should focus on whether people reach a confident next action
  with fewer comparisons and can explain why it was suggested. Routina currently
  does not use product Analytics, so any telemetry proposal requires a separate
  privacy decision; structured usability studies and direct feedback are the
  default validation path.

## Decision Scenarios for a Later Accepted Record

### Completion alternatives stay local

Given Exercise participates in the root ladder
And Walk, Gym, Swim, Running, and Hiking are its completion options
When the root ladder is shown
Then Exercise appears once
And its options appear only after opening Exercise
And completing a selected option can explicitly fulfill Exercise once.

### Containers do not inherit completion semantics

Given Company is an Area containing several tickets
When one ticket is completed
Then the ticket leaves or advances according to its own lifecycle
And Company remains available while other actionable work exists
And no Company completion is recorded.

### Temporary focus changes without metadata cascades

Given Company is primary today
When Family is made primary tomorrow
Then the Area order changes for tomorrow
And task-level Importance, Urgency, Pressure, estimates, and history do not change.

### Global finalists remain bounded

Given several Areas each have locally ordered tasks
When Routina builds the `What should I do now?` view
Then it shows only the best eligible candidate from each relevant Area
And it does not compare or render every lower-ranked task globally.

### Explicit constraints can override focus

Given Company is the primary Area
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

Given an Area is deleted
When it still owns tasks
Then those tasks move to an explicit Unsorted/root destination
And their task data, history, relationships, and non-Area metadata remain intact.

### Shared options do not create ambiguous ranking

Given one completion option can fulfill more than one parent
When it is ranked inside each parent
Then each parent retains its own tie-break order
And completing the option asks which eligible parent commitments to fulfill.

## Staged Decision Boundaries

1. **Implemented:** explicit completion options, root suppression, nested Mac
   ladders, scope-specific tie-break ranks, and manual parent fulfillment.
2. **Later decision:** durable Areas/containers and their relationship to Home
   Paths, tags, Goals, and unassigned tasks.
3. **Later decision:** temporary Area focus, expiration, persistence, sync, and
   whether focus applies per device or across devices.
4. **Later decision:** the bounded `What should I do now?` finalist surface,
   explainable exception precedence, and available-time context.
5. **Later decision:** iOS presentation and parity after the product semantics are
   validated on the Mac Task Ladder.

## Open Questions

- Should an Area be a new entity, a ladder-only catalog, or a projection of an
  existing Home Path? Reusing Home Path would couple Ladder organization to Home
  placement, which may violate user expectations.
- Does each task have one primary Area, or can it belong to several? Multiple
  ownership requires independent rank and deduplication semantics.
- Is the Area overview navigational only, or can Areas themselves be temporarily
  ordered without pretending they have task Importance/Urgency?
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
