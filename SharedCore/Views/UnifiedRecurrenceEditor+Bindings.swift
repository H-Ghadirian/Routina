import SwiftUI

extension UnifiedRecurrenceEditor {
    var cadenceOptions: [RoutineRecurrenceDraft.Cadence] {
        var options: [RoutineRecurrenceDraft.Cadence] = []
        if supportsNoSchedule {
            options.append(contentsOf: [.none, .manual])
        }
        options.append(contentsOf: [.afterCompletion, .scheduled])
        if supportsItemRunout {
            options.append(.itemRunout)
        }
        return options
    }

    var frequencyOptions: [RoutineAdvancedRecurrenceRule.Frequency] {
        if draft.cadence == .afterCompletion {
            return [.daily, .weekly, .monthly]
        }
        return RoutineAdvancedRecurrenceRule.Frequency.allCases
    }

    var intervalBounds: ClosedRange<Int> {
        draft.frequency == .hourly ? 1...168 : 1...365
    }

    var everyLabel: String {
        let unit = draft.frequency.unitName(for: draft.interval)
        if draft.cadence == .afterCompletion {
            return "Repeat \(draft.interval) \(unit) after completion"
        }
        return "Every \(draft.interval) \(unit)"
    }

    var requiredDetailsExplanation: String {
        switch draft.frequency {
        case .hourly:
            return "Hourly schedules need a fixed start to establish their first occurrence."
        case .yearly:
            return "Yearly schedules need a fixed start and time zone."
        case .daily, .weekly, .monthly:
            if draft.occurrenceTimes.count > 1 {
                return "Multiple times require fixed schedule details."
            }
            if draft.endMode != .never {
                return "An ending condition requires fixed schedule details."
            }
            if draft.monthlyPattern == .ordinalWeekday {
                return "A weekday position requires fixed schedule details."
            }
            return "Every-N schedules need a fixed start so the interval has a stable anchor."
        }
    }

    var fixedDetailsBinding: Binding<Bool> {
        Binding(
            get: { draft.usesFixedScheduleDetails },
            set: {
                draft = draft.settingFixedScheduleDetailsEnabled(
                    $0,
                    now: referenceDate,
                    calendar: calendar
                )
            }
        )
    }

    var startDateBinding: Binding<Date> {
        Binding(
            get: { draft.startDate ?? referenceDate },
            set: { value in
                updateDraft(
                    { $0.startDate = value },
                    alignsFixedStartToFirstOccurrenceTime: !fixedStartComponents.contains(.hourAndMinute)
                )
            }
        )
    }

    var timeZoneBinding: Binding<String> {
        Binding(
            get: { draft.timeZoneIdentifier ?? calendar.timeZone.identifier },
            set: { value in
                updateDraft { $0.timeZoneIdentifier = value }
            }
        )
    }

    var monthlyPatternBinding: Binding<RoutineAdvancedRecurrenceRule.MonthlyPattern> {
        Binding(
            get: { draft.monthlyPattern },
            set: { value in
                updateDraft { $0.monthlyPattern = value }
            }
        )
    }

    var endModeBinding: Binding<RoutineAdvancedRecurrenceRule.EndMode> {
        Binding(
            get: { draft.endMode },
            set: { value in
                updateDraft { $0.endMode = value }
            }
        )
    }

    var weekdaysBinding: Binding<[Int]> {
        Binding(
            get: {
                draft.weekdays.isEmpty
                    ? [calendar.component(.weekday, from: draft.startDate ?? referenceDate)]
                    : draft.weekdays
            },
            set: { value in
                updateDraft { $0.weekdays = value }
            }
        )
    }

    var monthDaysBinding: Binding<[Int]> {
        Binding(
            get: {
                draft.monthDays.isEmpty
                    ? [calendar.component(.day, from: draft.startDate ?? referenceDate)]
                    : draft.monthDays
            },
            set: { value in
                updateDraft { $0.monthDays = value }
            }
        )
    }

    var monthsOfYearBinding: Binding<[Int]> {
        Binding(
            get: {
                draft.monthsOfYear.isEmpty
                    ? [calendar.component(.month, from: draft.startDate ?? referenceDate)]
                    : draft.monthsOfYear
            },
            set: { value in
                updateDraft { $0.monthsOfYear = value }
            }
        )
    }

    func valueBinding<Value>(
        _ keyPath: WritableKeyPath<RoutineRecurrenceDraft, Value>
    ) -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                updateDraft { $0[keyPath: keyPath] = value }
            }
        )
    }

    func timeBinding(
        _ keyPath: WritableKeyPath<RoutineRecurrenceDraft, RoutineTimeOfDay>
    ) -> Binding<Date> {
        Binding(
            get: {
                draft[keyPath: keyPath].date(
                    on: draft.startDate ?? referenceDate,
                    calendar: calendar
                )
            },
            set: { value in
                updateDraft {
                    $0[keyPath: keyPath] = RoutineTimeOfDay.from(value, calendar: calendar)
                }
            }
        )
    }

    func indexedTimeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                guard draft.occurrenceTimes.indices.contains(index) else {
                    return draft.startDate ?? referenceDate
                }
                return draft.occurrenceTimes[index].date(
                    on: draft.startDate ?? referenceDate,
                    calendar: calendar
                )
            },
            set: { value in
                updateDraft(
                    { updated in
                        guard updated.occurrenceTimes.indices.contains(index) else { return }
                        updated.occurrenceTimes[index] = RoutineTimeOfDay.from(
                            value,
                            calendar: calendar
                        )
                    },
                    alignsFixedStartToFirstOccurrenceTime: true
                )
            }
        )
    }

    func selectCadence(_ cadence: RoutineRecurrenceDraft.Cadence) {
        draft = draft.selectingCadence(
            cadence,
            now: referenceDate,
            calendar: calendar
        )
    }

    func selectFrequency(_ frequency: RoutineAdvancedRecurrenceRule.Frequency) {
        draft = draft.selectingFrequency(
            frequency,
            now: referenceDate,
            calendar: calendar
        )
    }

    func addTime() {
        updateDraft(
            { updated in
                let last =
                    updated.occurrenceTimes.last
                    ?? RoutineTimeOfDay.from(updated.startDate ?? referenceDate, calendar: calendar)
                updated.occurrenceTimes.append(last.addingMinutes(60))
            },
            alignsFixedStartToFirstOccurrenceTime: true
        )
    }

    func removeTime(at index: Int) {
        updateDraft(
            { updated in
                guard updated.occurrenceTimes.count > 1,
                    updated.occurrenceTimes.indices.contains(index)
                else { return }
                updated.occurrenceTimes.remove(at: index)
            },
            alignsFixedStartToFirstOccurrenceTime: true
        )
    }

    func updateDraft(
        _ update: (inout RoutineRecurrenceDraft) -> Void,
        alignsFixedStartToFirstOccurrenceTime: Bool = false
    ) {
        var updated = draft
        update(&updated)
        if updated.requiresFixedScheduleDetails {
            updated = updated.settingFixedScheduleDetailsEnabled(
                true,
                now: referenceDate,
                calendar: calendar
            )
        }
        if alignsFixedStartToFirstOccurrenceTime {
            updated = updated.aligningFixedStartToFirstOccurrenceTime(
                calendar: calendar
            )
        }
        draft = updated.normalized()
    }

    func cadenceTitle(_ cadence: RoutineRecurrenceDraft.Cadence) -> String {
        switch cadence {
        case .none: return "No schedule"
        case .manual: return "When needed"
        case .itemRunout: return "Item runout"
        case .afterCompletion: return "After done"
        case .scheduled: return "On schedule"
        }
    }

    func frequencyTitle(_ frequency: RoutineAdvancedRecurrenceRule.Frequency) -> String {
        switch frequency {
        case .hourly: return "Hour"
        case .daily: return "Day"
        case .weekly: return "Week"
        case .monthly: return "Month"
        case .yearly: return "Year"
        }
    }

    func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    var summarySystemImage: String {
        switch draft.cadence {
        case .none: return "arrow.trianglehead.2.clockwise.rotate.90.slash"
        case .manual: return "archivebox"
        case .itemRunout: return "checklist"
        case .afterCompletion: return "arrow.clockwise"
        case .scheduled: return "calendar.badge.clock"
        }
    }
}
