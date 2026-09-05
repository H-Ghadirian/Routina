import SwiftData
import SwiftUI

extension RoutineEventEditorView {
    func normalizeDates() {
        if isAllDay {
            startDate = calendar.startOfDay(for: startDate)
            endDate = max(calendar.startOfDay(for: endDate), startDate)
        } else if endDate <= startDate {
            endDate = startDate.addingTimeInterval(60 * 60)
        }
    }

    func rebaseReminderIfUsingLeadTime(previousEventDate: Date?) {
        let leadMinutes = TaskFormReminderLeadTime.matchedLeadMinutes(
            eventDate: previousEventDate,
            reminderAt: reminderAt
        )
        guard let leadMinutes, let eventDate = reminderEventDate else { return }
        reminderAt = TaskFormReminderLeadTime.reminderDate(
            eventDate: eventDate,
            leadMinutes: leadMinutes
        )
    }

    func cancel() {
        if event == nil {
            CreationDraftPersistence.clear(.event)
        }
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }

    func save() {
        guard canSave else { return }
        let now = Date()
        let target = event ?? RoutineEvent(createdAt: now, updatedAt: now)
        target.title = RoutineEvent.cleanedText(title)
        target.notes = isNotesEnabled ? RoutineEvent.cleanedText(notesText) : event?.notes
        target.emoji = RoutineEvent.cleanedText(emoji)
        target.tags = tags
        target.isAllDay = isAllDay
        target.startedAt = normalizedStartDate
        target.endedAt = normalizedEndDate
        target.reminderAt = reminderAt
        if target.createdAt == nil {
            target.createdAt = now
        }
        target.updatedAt = now

        if event == nil {
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            reconcileEventNotification(for: target, referenceDate: now)
            if event == nil {
                CreationDraftPersistence.clear(.event)
            }
            onSaved?(target.id)
            dismiss()
        } catch {
            errorText = "Could not save the event."
        }
    }

    func reconcileEventNotification(
        for event: RoutineEvent,
        referenceDate: Date
    ) {
        let payload = NotificationCoordinator.notificationPayload(
            for: event,
            referenceDate: referenceDate,
            calendar: calendar
        )
        if NotificationCoordinator.shouldScheduleNotification(
            for: event,
            referenceDate: referenceDate
        ) {
            Task {
                await NotificationCoordinator.scheduleNotification(payload)
            }
        } else {
            NotificationCoordinator.cancelNotification(payload.identifier)
        }
    }
}
