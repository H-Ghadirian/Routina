import ComposableArchitecture
import SwiftUI

extension TimelineView {
    @ViewBuilder
    func timelineRow(_ entry: TimelineEntry) -> some View {
        if let taskID = entry.taskID {
            NavigationLink(value: taskID) {
                timelineRowContent(entry)
            }
        } else if entry.isEmotion, let emotion = emotionLog(for: entry) {
            NavigationLink {
                EmotionLogDetailView(emotion: emotion)
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isEvent, let event = event(for: entry) {
            NavigationLink {
                RoutineEventDetailView(event: event)
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isNote, let note = note(for: entry) {
            NavigationLink {
                RoutineNoteDetailView(
                    note: note,
                    attachments: noteAttachments(for: note)
                )
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isPlaceCheckIn, let session = placeCheckInSession(for: entry) {
            NavigationLink {
                PlaceCheckInSessionDetailView(session: session)
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isSleep {
            Button {
                RoutinaDeepLinkDispatcher.open(.sleep(entry.id))
            } label: {
                timelineRowContent(entry)
            }
            .buttonStyle(.plain)
        } else if entry.isAway, let session = awaySession(for: entry) {
            Button {
                editingAwaySession = session
            } label: {
                timelineRowContent(entry)
            }
            .buttonStyle(.plain)
        } else {
            timelineRowContent(entry)
        }
    }

    private func timelineRowContent(_ entry: TimelineEntry) -> some View {
        HStack(spacing: 12) {
            if timelineRowVisibility.shows(.icon) {
                Text(entry.taskEmoji)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .routinaScrollingRoundedFill(
                        cornerRadius: 8,
                        tint: .secondary,
                        tintOpacity: 0.06
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if timelineRowVisibility.shows(.subtitle) {
                    Text(timelineSubtitle(for: entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if timelineRowVisibility.shows(.kindBadge) {
                Text(timelineKindLabel(for: entry))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .routinaScrollingPillFill(
                        tint: timelineKindColor(for: entry),
                        tintOpacity: 0.15
                    )
                    .foregroundStyle(timelineKindColor(for: entry))
            }
        }
        .padding(.vertical, 2)
    }

    private var timelineRowVisibility: HomeTimelineRowVisibility {
        HomeTimelineRowVisibility(storageRawValue: timelineRowHiddenFieldsRawValue)
    }

    private func timelineKindLabel(for entry: TimelineEntry) -> String {
        TimelineEntryKindPresentation.label(for: entry)
    }

    private func timelineKindColor(for entry: TimelineEntry) -> Color {
        TimelineEntryKindPresentation.tint(for: entry).color
    }

    private func timelineSubtitle(for entry: TimelineEntry) -> String {
        if entry.isSleep {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            let endedAt = entry.endTimestamp ?? entry.timestamp
            let range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            if let durationSeconds = entry.durationSeconds {
                return "\(range) · \(SleepSessionFormatting.durationText(seconds: durationSeconds))"
            }
            return range
        }

        if entry.isPlaceCheckIn {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            let range: String
            if let endedAt = entry.endTimestamp {
                range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            } else {
                range = "Since \(startedAt.formatted(date: .omitted, time: .shortened))"
            }
            let duration = entry.durationSeconds.map { PlaceCheckInFormatting.durationText(seconds: $0) }
            return [range, duration, entry.activityTitle].compactMap(\.self).joined(separator: " · ")
        }

        if entry.isEmotion {
            return [
                entry.timestamp.formatted(date: .omitted, time: .shortened),
                entry.activityTitle,
            ].compactMap(\.self).joined(separator: " · ")
        }

        if entry.isEvent {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            guard let endedAt = entry.endTimestamp, endedAt > startedAt else {
                return startedAt.formatted(date: .omitted, time: .shortened)
            }
            if calendar.isDate(startedAt, inSameDayAs: endedAt) {
                return "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            }
            return RoutineEventDateFormatting.text(
                startedAt: startedAt,
                endedAt: endedAt,
                isAllDay: calendar.startOfDay(for: startedAt) == startedAt,
                calendar: calendar
            )
        }

        if entry.isNote {
            let mediaSummary = RoutineNoteMediaSummary.text(
                hasImage: entry.hasImage,
                hasFileAttachment: entry.hasFileAttachment,
                hasVoiceNote: entry.hasVoiceNote
            )
            return [
                entry.timestamp.formatted(date: .omitted, time: .shortened),
                mediaSummary,
            ].compactMap(\.self).joined(separator: " · ")
        }

        if entry.isFocus {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            let range: String
            if let endedAt = entry.endTimestamp {
                range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            } else {
                range = "Since \(startedAt.formatted(date: .omitted, time: .shortened))"
            }
            let duration = entry.durationSeconds.map { FocusSessionFormatting.compactDurationText(seconds: $0) }
            return [range, duration, entry.activityTitle].compactMap(\.self).joined(separator: " · ")
        }

        if entry.isAway {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            let range: String
            if let endedAt = entry.endTimestamp {
                range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            } else {
                range = "Since \(startedAt.formatted(date: .omitted, time: .shortened))"
            }
            let duration = entry.durationSeconds.map { AwaySessionFormatting.durationText(seconds: $0) }
            return [range, duration, entry.activityTitle].compactMap(\.self).joined(separator: " · ")
        }

        return entry.timestamp.formatted(date: .omitted, time: .shortened)
    }

    private func note(for entry: TimelineEntry) -> RoutineNote? {
        notes.first { $0.id == entry.id }
    }

    private func event(for entry: TimelineEntry) -> RoutineEvent? {
        events.first { $0.id == entry.id }
    }

    private func emotionLog(for entry: TimelineEntry) -> EmotionLog? {
        emotionLogs.first { $0.id == entry.id }
    }

    private func placeCheckInSession(for entry: TimelineEntry) -> PlaceCheckInSession? {
        guard isPlacesEnabled else { return nil }
        return placeCheckInSessions.first { $0.id == entry.id }
    }

    private func awaySession(for entry: TimelineEntry) -> AwaySession? {
        awaySessions.first { $0.id == entry.id }
    }

    func noteAttachments(for note: RoutineNote) -> [RoutineNoteAttachment] {
        noteAttachments
            .filter { $0.noteID == note.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

}
