import Foundation

extension RoutineRecurrenceDraft {
    func replacingCadence(_ cadence: Cadence) -> Self {
        var updated = self
        updated.cadence = cadence
        return updated
    }

    var usesFixedScheduleDetails: Bool {
        guard cadence == .scheduled else { return false }
        return requiresFixedScheduleDetails
            || startDate != nil
            || timeZoneIdentifier != nil
            || !occurrenceTimes.isEmpty
    }

    var requiresFixedScheduleDetails: Bool {
        guard cadence == .scheduled else { return false }
        if interval > 1 || endMode != .never || occurrenceTimes.count > 1 {
            return true
        }

        switch frequency {
        case .hourly, .yearly:
            return true
        case .monthly:
            return monthlyPattern == .ordinalWeekday
        case .daily, .weekly:
            return false
        }
    }

    var canDisableFixedScheduleDetails: Bool {
        guard cadence == .scheduled,
            !requiresFixedScheduleDetails,
            frequency == .daily || frequency == .weekly || frequency == .monthly,
            occurrenceTimes.count <= 1
        else { return false }

        if case .anyTime = availability {
            return true
        }
        if case .window = availability {
            return occurrenceTimes.count <= 1
        }
        return occurrenceTimes.isEmpty
    }

    func selectingCadence(
        _ cadence: Cadence,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Self {
        var updated = self
        updated.cadence = cadence

        if cadence == .afterCompletion,
            updated.frequency == .hourly || updated.frequency == .yearly
        {
            updated.frequency = .daily
        }

        if cadence == .afterCompletion,
            case .anyTime = updated.availability,
            let occurrenceTime = updated.occurrenceTimes.first
        {
            updated.availability = .at(occurrenceTime)
        }

        if cadence == .scheduled, updated.usesFixedScheduleDetails {
            updated.ensureFixedScheduleDetails(now: now, calendar: calendar)
        }
        return updated.normalized()
    }

    func selectingFrequency(
        _ frequency: RoutineAdvancedRecurrenceRule.Frequency,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Self {
        var updated = self
        updated.frequency = frequency

        if updated.weekdays.isEmpty {
            updated.weekdays = [calendar.component(.weekday, from: now)]
        }
        if updated.monthDays.isEmpty {
            updated.monthDays = [calendar.component(.day, from: now)]
        }
        if updated.monthsOfYear.isEmpty {
            updated.monthsOfYear = [calendar.component(.month, from: now)]
        }

        if updated.requiresFixedScheduleDetails {
            updated.ensureFixedScheduleDetails(now: now, calendar: calendar)
        }
        return updated.normalized()
    }

    func settingInterval(
        _ interval: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Self {
        var updated = self
        updated.interval = max(interval, 1)
        if updated.requiresFixedScheduleDetails {
            updated.ensureFixedScheduleDetails(now: now, calendar: calendar)
        }
        return updated.normalized()
    }

    func settingFixedScheduleDetailsEnabled(
        _ isEnabled: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Self {
        var updated = self
        if isEnabled {
            updated.ensureFixedScheduleDetails(now: now, calendar: calendar)
        } else if updated.canDisableFixedScheduleDetails {
            if case .anyTime = updated.availability,
                let occurrenceTime = updated.occurrenceTimes.first
            {
                updated.availability = .at(occurrenceTime)
            }
            updated.startDate = nil
            updated.timeZoneIdentifier = nil
            updated.occurrenceTimes = []
        }
        return updated.normalized()
    }

    func aligningFixedStartToFirstOccurrenceTime(
        calendar: Calendar = .current
    ) -> Self {
        guard cadence == .scheduled,
            frequency != .hourly,
            let startDate,
            let firstOccurrenceTime = occurrenceTimes.min(by: {
                $0.minutesFromStartOfDay < $1.minutesFromStartOfDay
            })
        else { return self }

        var updated = self
        updated.startDate = firstOccurrenceTime.date(
            on: startDate,
            calendar: calendar
        )
        return updated.normalized()
    }

    private mutating func ensureFixedScheduleDetails(
        now: Date,
        calendar: Calendar
    ) {
        let resolvedStart = startDate ?? now
        startDate = resolvedStart
        timeZoneIdentifier =
            TimeZone(identifier: timeZoneIdentifier ?? "")?.identifier
            ?? calendar.timeZone.identifier

        if endDate <= resolvedStart {
            endDate = calendar.date(byAdding: .year, value: 1, to: resolvedStart) ?? resolvedStart
        }

        if weekdays.isEmpty {
            weekdays = [calendar.component(.weekday, from: resolvedStart)]
        }
        if monthDays.isEmpty {
            monthDays = [calendar.component(.day, from: resolvedStart)]
        }
        if monthsOfYear.isEmpty {
            monthsOfYear = [calendar.component(.month, from: resolvedStart)]
        }

        if case let .at(timeOfDay) = availability {
            occurrenceTimes = [timeOfDay]
            availability = .anyTime
        } else if case let .window(timeRange) = availability,
            frequency != .hourly
        {
            startDate = timeRange.start.date(on: resolvedStart, calendar: calendar)
            occurrenceTimes = [timeRange.start]
        } else if frequency != .hourly, occurrenceTimes.isEmpty {
            occurrenceTimes = [RoutineTimeOfDay.from(resolvedStart, calendar: calendar)]
        }
    }
}
