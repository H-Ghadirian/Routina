# 0705: Refresh Cross-Platform Development Screenshot Fixtures

## Status

Accepted

## Date

2026-08-30

## Revises

- [0465: Prepare the Mac Development App for Screenshots](0465-prepare-mac-development-app-for-screenshots.md)

## Context

The original screenshot fixture was intentionally limited to the Mac development
app and inserted deterministic records only when they were missing. That was safe
for the first Mac release, but it no longer supports release preparation well:
the first iOS release needs an equivalent development store, older fixture dates
and copy remain stale on rerun, and the product now includes important production
concepts that the original dataset did not represent.

Release screenshots need coherent, meaningful content without copying personal or
production data. Re-preparing an established development store must update the
records Routina owns while leaving unrelated development work intact, and no
preparation path may become available to a production build.

## Decision

- Both the iOS and macOS development apps honor the one-shot
  `ROUTINA_SCREENSHOT_DATA_SEED=1` launch request. The optional
  `ROUTINA_SCREENSHOT_DATA_SEED_EXIT=1` request exits after the preparation
  attempt. Production apps reject the request.
- Mac Settings -> Appearance retains the in-app `Generate Screenshot Data`
  action and development-badge control. iOS does not add a release-preparation
  control to the app's ordinary interface; its store is prepared through the
  development-only launch request.
- The generator owns records and custom sections in a reserved deterministic ID
  namespace. A rerun refreshes those owned records with current date-relative
  values, inserts newly introduced fixture records, and merges its sections into
  durable preferences. It does not delete, replace, or rewrite unrelated
  development data.
- The fixture tells one plausible release-preparation story across platforms. It
  covers repeating and one-time tasks, Due and Gentle rhythms, Interval and
  Calendar cadence, a cadence-free when-needed routine, Task Ladder values and
  time rules, custom Home and Backlog hierarchy, relationships and blocking,
  built-in Flags, titled links, a destination and reminder, Planner blocks,
  Focus, Timeline history, and Stats-supporting activity.
- Context records that remain development experiments may support internal visual
  testing, but their presence in a development fixture does not imply production
  availability.
- Seeding prepares data only. It never takes a screenshot, records the screen, or
  changes the user's permission requirement for captures.

## Consequences

- Release preparation can build a comparable, current iOS and Mac story without
  borrowing production data.
- Rerunning the generator repairs stale fixture copy and dates instead of leaving
  an old deterministic record untouched or accumulating duplicates.
- Existing non-fixture content in either development store survives preparation.
- The Mac app retains its convenient manual preparation action; iOS release
  preparation remains an explicit developer launch operation.
- Production binaries cannot seed fixture data even if the launch variable is
  supplied.
