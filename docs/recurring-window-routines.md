# Recurring Window Routines

## Goal

Support routines such as:

- Travel from May 10 to May 18 every year
- Visit parents from the 1st to the 3rd every month
- Renew something during a valid window twice per year
- Go travel once in a while, without an exact cadence
- Keep travel visible all the time, but softly indicate that a long period has passed
- Mark travel as ongoing while the user is in the middle of a trip

Not all of these are a single due instant. Some are recurring occurrences with a start and end window. Some are soft, always-visible routines with no fixed next date at all.

## Why this should be a first-class schedule type

The current model is centered on one next due date:

- `RoutineRecurrenceRule` describes interval, daily, weekly, or monthly recurrence.
- `RoutineDateMath.dueDate(for:)` returns one due date.
- `RoutineTask.deadline` is only for one-off todos.

That works well for standard routines, but travel-like routines can need one of two very different behaviors:

- an occurrence cadence
- a valid date range for each occurrence
- completion scoped to one occurrence window

Or:

- no fixed next date
- no fixed duration
- always visible in the list
- soft resurfacing based on time since last completion
- an "ongoing" state that the user can turn on manually

Trying to force this into `deadline`, snooze, or pause will make the behavior hard to explain and hard to maintain.

## Recommended model

Keep the existing recurrence system for normal routines, add a separate schedule concept for recurring windows, and add a flexible resurfacing mode for "once in a while" routines.

### New types

```swift
import Foundation

enum RoutineSchedulePattern: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case standard
    case recurringWindow
    case flexibleGap
}

enum RoutineWindowRecurrence: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case monthly
    case yearly
    case customMonths
}

enum RoutineWindowCompletionPolicy: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case oncePerWindow
    case multipleTimesWithinWindow
}

struct RoutineWindowRule: Codable, Equatable, Hashable, Sendable {
    var recurrence: RoutineWindowRecurrence

    // For yearly windows, month/day define the window shape.
    var startMonth: Int
    var startDay: Int
    var endMonth: Int
    var endDay: Int

    // For custom month intervals such as "every 6 months" or "every 3 months".
    var monthInterval: Int?

    // Optional anchor month for patterns like "twice a year starting in May".
    var anchorMonth: Int?

    var completionPolicy: RoutineWindowCompletionPolicy

    init(
        recurrence: RoutineWindowRecurrence,
        startMonth: Int,
        startDay: Int,
        endMonth: Int,
        endDay: Int,
        monthInterval: Int? = nil,
        anchorMonth: Int? = nil,
        completionPolicy: RoutineWindowCompletionPolicy = .oncePerWindow
    ) {
        self.recurrence = recurrence
        self.startMonth = min(max(startMonth, 1), 12)
        self.startDay = min(max(startDay, 1), 31)
        self.endMonth = min(max(endMonth, 1), 12)
        self.endDay = min(max(endDay, 1), 31)
        self.monthInterval = monthInterval.map { min(max($0, 1), 12) }
        self.anchorMonth = anchorMonth.map { min(max($0, 1), 12) }
        self.completionPolicy = completionPolicy
    }
}

struct RoutineOccurrenceWindow: Equatable, Hashable, Sendable {
    var start: Date
    var end: Date
    var id: String
}

struct RoutineFlexibleRule: Codable, Equatable, Hashable, Sendable {
    // Soft threshold after completion. Once this much time has passed, the UI can
    // gently increase emphasis, but the routine is still never overdue.
    var softResurfaceAfterDays: Int

    // Optional "good time" window. Example: travel is generally better in summer,
    // but not strictly required to happen inside that season.
    var preferredWindow: RoutineWindowRule?

    init(
        softResurfaceAfterDays: Int,
        preferredWindow: RoutineWindowRule? = nil
    ) {
        self.softResurfaceAfterDays = min(max(softResurfaceAfterDays, 1), 3650)
        self.preferredWindow = preferredWindow
    }
}

enum RoutineActivityState: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case idle
    case ongoing
}
```

### Extend `RoutineTask`

This keeps current routines unchanged and only activates window logic when the new pattern is selected.

```swift
@Model
final class RoutineTask {
    var schedulePatternRawValue: String = RoutineSchedulePattern.standard.rawValue
    var windowRuleStorage: String = ""
    var flexibleRuleStorage: String = ""
    var activityStateRawValue: String = RoutineActivityState.idle.rawValue
    var ongoingSince: Date?

    var schedulePattern: RoutineSchedulePattern {
        get { RoutineSchedulePattern(rawValue: schedulePatternRawValue) ?? .standard }
        set { schedulePatternRawValue = newValue.rawValue }
    }

    var windowRule: RoutineWindowRule? {
        get { RoutineWindowRuleStorage.deserialize(windowRuleStorage) }
        set { windowRuleStorage = RoutineWindowRuleStorage.serialize(newValue) }
    }

    var flexibleRule: RoutineFlexibleRule? {
        get { RoutineFlexibleRuleStorage.deserialize(flexibleRuleStorage) }
        set { flexibleRuleStorage = RoutineFlexibleRuleStorage.serialize(newValue) }
    }

    var isRecurringWindowRoutine: Bool {
        schedulePattern == .recurringWindow && windowRule != nil
    }

    var isFlexibleGapRoutine: Bool {
        schedulePattern == .flexibleGap && flexibleRule != nil
    }

    var activityState: RoutineActivityState {
        get { RoutineActivityState(rawValue: activityStateRawValue) ?? .idle }
        set { activityStateRawValue = newValue.rawValue }
    }

    var isOngoing: Bool {
        activityState == .ongoing
    }
}
```

Storage helpers would mirror `RoutineRecurrenceRuleStorage`.

## Date math API

Add window-aware helpers to `RoutineDateMath` instead of overloading existing `dueDate` logic too much.

### New API surface

```swift
enum RoutineDateMath {
    static func activeWindow(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineOccurrenceWindow?

    static func nextWindow(
        for task: RoutineTask,
        after referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineOccurrenceWindow?

    static func previousWindow(
        for task: RoutineTask,
        before referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineOccurrenceWindow?

    static func isInActiveWindow(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool

    static func isCompletedForActiveWindow(
        task: RoutineTask,
        logs: [RoutineLog],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool

    static func flexibleAvailableDate(
        for task: RoutineTask,
        calendar: Calendar = .current
    ) -> Date?

    static func hasPassedFlexibleSoftThreshold(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool

    static func isInsidePreferredWindow(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool

    static func elapsedDaysSinceLastCompletion(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int
}
```

### Suggested behavior

- Before the window: routine is upcoming, not due yet
- Inside the window:
  - `oncePerWindow`: mark done once, then consider satisfied until next window
  - `multipleTimesWithinWindow`: allow repeated completions if needed
- After the window:
  - if not completed, mark missed
  - if completed, wait for the next occurrence

For `flexibleGap`:

- the routine stays visible all the time
- after completion, the UI stays quiet for a while
- once the soft threshold has passed, the card gets a little more emphasis
- never show as overdue or missed
- if a preferred window exists, show a softer label such as "good time now" rather than enforcing it
- if the user starts the activity, show `Ongoing`

## How to build the window

### Yearly example

Travel May 10 to May 18 every year:

```swift
RoutineWindowRule(
    recurrence: .yearly,
    startMonth: 5,
    startDay: 10,
    endMonth: 5,
    endDay: 18,
    completionPolicy: .oncePerWindow
)
```

### Monthly example

Pay rent review from the 1st to the 3rd every month:

```swift
RoutineWindowRule(
    recurrence: .monthly,
    startMonth: 1, // ignored for monthly generation except as storage fallback
    startDay: 1,
    endMonth: 1,   // ignored for monthly generation except as storage fallback
    endDay: 3,
    completionPolicy: .oncePerWindow
)
```

### Twice-a-year example

Travel window from May 10 to May 18, every 6 months:

```swift
RoutineWindowRule(
    recurrence: .customMonths,
    startMonth: 5,
    startDay: 10,
    endMonth: 5,
    endDay: 18,
    monthInterval: 6,
    anchorMonth: 5,
    completionPolicy: .oncePerWindow
)
```

This is better than pretending "twice a year" always means January and July. The anchor makes the cadence predictable.

### Once-in-a-while example

Travel again after roughly 6 months, but not on a strict schedule:

```swift
RoutineFlexibleRule(
    softResurfaceAfterDays: 180
)
```

Travel once in a while, ideally during summer:

```swift
RoutineFlexibleRule(
    softResurfaceAfterDays: 180,
    preferredWindow: RoutineWindowRule(
        recurrence: .yearly,
        startMonth: 6,
        startDay: 1,
        endMonth: 9,
        endDay: 15,
        completionPolicy: .oncePerWindow
    )
)
```

This is different from "every 6 months". It is a reminder to bring the routine back gently after a cooling-off period, not a promise that the user must do it on schedule.

This seems like the best fit for travel when:

- the trip duration is unknown
- the next trip timing is unknown
- the user still wants to see travel in the app
- the app should feel supportive, not demanding

## Important edge cases

### Cross-year windows

Example: Dec 28 to Jan 5 every year.

The date math should allow `endMonth/endDay` to be earlier in the calendar than `startMonth/startDay`, which means the window crosses into the next year.

### Short months

Example: start on the 31st.

Clamp to the last valid day of the month for the generated occurrence:

- Feb 31 -> Feb 28/29
- Apr 31 -> Apr 30

### Logging

For `oncePerWindow`, completion should be checked against logs inside the occurrence window, not just "same day as lastDone".

Suggested helper:

```swift
extension Array where Element == RoutineLog {
    func containsCompletion(
        within window: RoutineOccurrenceWindow,
        calendar: Calendar = .current
    ) -> Bool {
        contains { log in
            guard log.kind == .completed, let timestamp = log.timestamp else { return false }
            return timestamp >= window.start && timestamp <= window.end
        }
    }
}
```

For `flexibleGap`, `lastDone` is enough to compute when the routine should get soft emphasis again:

```swift
extension RoutineDateMath {
    static func flexibleAvailableDate(
        for task: RoutineTask,
        calendar: Calendar = .current
    ) -> Date? {
        guard task.isFlexibleGapRoutine, let flexibleRule = task.flexibleRule else { return nil }
        guard let lastDone = task.lastDone else { return task.createdAt }
        return calendar.date(byAdding: .day, value: flexibleRule.softResurfaceAfterDays, to: lastDone)
    }
}
```

Suggested helper:

```swift
extension RoutineDateMath {
    static func hasPassedFlexibleSoftThreshold(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let availableDate = flexibleAvailableDate(for: task, calendar: calendar) else { return false }
        return calendar.startOfDay(for: referenceDate) >= calendar.startOfDay(for: availableDate)
    }
}
```

### Ongoing activity

Travel also benefits from a current-state marker even when there is no fixed duration.

Recommended behavior:

- user can tap `Start Ongoing`
- task shows an `Ongoing` label immediately
- metadata can show `Started 3 days ago`
- when the user taps `Finish`, set `lastDone = now`, clear `ongoingSince`, and return to idle

Suggested fields:

```swift
extension RoutineTask {
    func startOngoing(at date: Date) {
        activityState = .ongoing
        ongoingSince = date
    }

    func finishOngoing(at date: Date) {
        activityState = .idle
        ongoingSince = nil
        lastDone = date
    }
}
```

This avoids needing a fixed duration while still letting the app say "this is happening right now".

## UI recommendation

Do not overload the existing recurrence picker too much. Add a top-level choice in the schedule section:

- Standard repeat
- Recurring window

For recurring window, show:

- recurrence: monthly / yearly / every N months
- window start: month + day
- window end: month + day
- completion policy: once per window

For flexible resurfacing, show:

- softly highlight after: N days / weeks / months
- optional preferred season/window
- helper text: "This stays visible and never becomes overdue."
- optional toggle/action: `Start Ongoing`

### Home screen states

Instead of only "due/overdue", expose:

- Upcoming: "Starts May 10"
- Active: "Active until May 18"
- Completed: "Done for this trip"
- Missed: "Missed May 10 to May 18"
- Cooling down: "Come back in 3 months"
- Quiet: "Last time 2 months ago"
- Soft reminder: "6 months since last time"
- Available again: "Ready whenever"
- Good time now: "Suggested this season"
- Ongoing: "Started 3 days ago"

### Color treatment

For flexible routines, avoid warning colors.

Suggested visual language:

- normal state: default card styling
- soft threshold passed: slightly richer tint of the task color, or a subtle neutral accent
- preferred season active: gentle accent, not red/orange
- ongoing: stable badge or pill, not an error treatment

Travel should feel like a soft nudge, not a warning.

## Migration strategy

Keep migration low-risk:

1. Default all existing tasks to `schedulePattern = .standard`
2. Leave `windowRuleStorage` empty for all existing tasks
3. Leave `flexibleRuleStorage` empty for all existing tasks
4. Only use window math when `isRecurringWindowRoutine == true`
5. Only use resurfacing logic when `isFlexibleGapRoutine == true`
6. Only use `ongoingSince` and `activityState` when the UI supports it

This avoids changing current task behavior.

## Minimal implementation plan

### Phase 1

- Add `RoutineSchedulePattern`
- Add `RoutineWindowRule` and storage helper
- Add `RoutineFlexibleRule` and storage helper
- Add `RoutineActivityState`
- Add fields to `RoutineTask`
- Add pure date math for `activeWindow`, `nextWindow`, completion-in-window checks, and flexible resurfacing
- Add tests for yearly, monthly, 6-month, cross-year, and 31st-day cases
- Add tests for flexible resurfacing with and without a preferred window
- Add tests for start/finish ongoing transitions

### Phase 2

- Add Add Routine form support
- Add Task Detail edit support
- Update Home display metadata
- Update mark-done rules for `oncePerWindow`

### Phase 3

- Add better labels such as upcoming, active, completed-for-window, and missed
- Decide whether missed windows should remain visible or collapse after a grace period

## My recommendation for the first shipped version

Start with the smallest useful version:

- `recurringWindow`
- `yearly`
- `monthly`
- `customMonths`
- `oncePerWindow`
- `flexibleGap`
- `softResurfaceAfterDays`
- `ongoing`

Skip multi-completion windows and advanced rules until the first version feels right in the app.

That gives you a clean path for travel, seasonal routines, renewal windows, event prep windows, and low-pressure "once in a while" routines without breaking the current recurrence model.
