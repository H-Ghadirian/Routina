import SwiftUI

extension RoutineEventEditorView {
    var canSave: Bool {
        RoutineEvent.cleanedText(title) != nil
            && normalizedEndDate > normalizedStartDate
    }

    var currentDraftSnapshot: RoutineEventDraftSnapshot {
        RoutineEventDraftSnapshot(
            title: title,
            notesText: isNotesEnabled ? notesText : "",
            emoji: emoji,
            isAllDay: isAllDay,
            startDate: startDate,
            endDate: endDate,
            reminderAt: reminderAt,
            tags: tags,
            tagDraft: tagDraft
        )
    }

    var normalizedStartDate: Date {
        if isAllDay {
            return calendar.startOfDay(for: startDate)
        }
        return startDate
    }

    var normalizedEndDate: Date {
        if isAllDay {
            let endDay = calendar.startOfDay(for: endDate)
            let startDay = calendar.startOfDay(for: startDate)
            let visibleEndDay = max(endDay, startDay)
            return calendar.date(byAdding: .day, value: 1, to: visibleEndDay) ?? visibleEndDay
        }
        return max(endDate, startDate.addingTimeInterval(60))
    }

    var allDayStartBinding: Binding<Date> {
        Binding(
            get: { startDate },
            set: { newValue in
                let previousEventDate = reminderEventDate
                startDate = calendar.startOfDay(for: newValue)
                if calendar.startOfDay(for: endDate) < calendar.startOfDay(for: startDate) {
                    endDate = startDate
                }
                rebaseReminderIfUsingLeadTime(previousEventDate: previousEventDate)
            }
        )
    }

    var allDayEndBinding: Binding<Date> {
        Binding(
            get: {
                guard
                    let adjusted = calendar.date(
                        byAdding: .second,
                        value: -1,
                        to: normalizedEndDate
                    )
                else {
                    return endDate
                }
                return calendar.startOfDay(for: adjusted)
            },
            set: { newValue in
                let previousEventDate = reminderEventDate
                endDate = max(
                    calendar.startOfDay(for: newValue),
                    calendar.startOfDay(for: startDate)
                )
                rebaseReminderIfUsingLeadTime(previousEventDate: previousEventDate)
            }
        )
    }

    var timedStartBinding: Binding<Date> {
        Binding(
            get: { startDate },
            set: { newValue in
                let previousEventDate = reminderEventDate
                let oldDuration = max(endDate.timeIntervalSince(startDate), 60 * 15)
                startDate = newValue
                if endDate <= startDate {
                    endDate = startDate.addingTimeInterval(oldDuration)
                }
                rebaseReminderIfUsingLeadTime(previousEventDate: previousEventDate)
            }
        )
    }

    var timedEndBinding: Binding<Date> {
        Binding(
            get: { endDate },
            set: { newValue in
                let previousEventDate = reminderEventDate
                endDate = max(newValue, startDate.addingTimeInterval(60))
                rebaseReminderIfUsingLeadTime(previousEventDate: previousEventDate)
            }
        )
    }

    var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { reminderAt != nil },
            set: { isEnabled in
                reminderAt = isEnabled ? (reminderAt ?? defaultReminderDate) : nil
            }
        )
    }

    var reminderDateBinding: Binding<Date> {
        Binding(
            get: { reminderAt ?? defaultReminderDate },
            set: { reminderAt = $0 }
        )
    }

    var reminderLeadMinutesBinding: Binding<Int?> {
        Binding(
            get: {
                TaskFormReminderLeadTime.matchedLeadMinutes(
                    eventDate: reminderEventDate,
                    reminderAt: reminderAt
                )
            },
            set: { leadMinutes in
                guard let leadMinutes, let eventDate = reminderEventDate else { return }
                reminderAt = TaskFormReminderLeadTime.reminderDate(
                    eventDate: eventDate,
                    leadMinutes: leadMinutes
                )
            }
        )
    }

    var reminderEventDate: Date? {
        RoutineEvent.reminderEventDate(
            startedAt: normalizedStartDate,
            isAllDay: isAllDay,
            calendar: calendar
        )
    }

    var defaultReminderDate: Date {
        RoutineEvent.defaultReminderDate(
            startedAt: normalizedStartDate,
            isAllDay: isAllDay,
            calendar: calendar
        )
    }

    var editorTitle: String {
        event == nil ? "New Event" : "Edit Event"
    }

    var notificationSection: some View {
        Section("Notification") {
            Toggle("Set notification", isOn: reminderEnabledBinding)
            if reminderAt != nil {
                if let reminderEventDate {
                    Picker("When", selection: reminderLeadMinutesBinding) {
                        Text("Custom time").tag(Optional<Int>.none)
                        ForEach(TaskFormReminderLeadTime.allCases) { option in
                            Text(option.title).tag(Optional(option.rawValue))
                        }
                    }

                    Text(
                        isAllDay
                            ? "Event: \(reminderEventDate.formatted(date: .abbreviated, time: .omitted))"
                            : "Event: \(reminderEventDate.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                DatePicker(
                    reminderEventDate == nil ? "Notification" : "Custom time",
                    selection: reminderDateBinding
                )
            }
        }
    }
}
