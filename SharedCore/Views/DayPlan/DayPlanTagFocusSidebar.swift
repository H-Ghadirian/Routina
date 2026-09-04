import SwiftData
import SwiftUI

struct DayPlanTagFocusSidebar: View {
    @Environment(\.modelContext) private var modelContext

    let session: FocusSession
    let calendar: Calendar
    let onDismiss: () -> Void

    @State private var startedAt: Date
    @State private var durationMinutes: Int
    @State private var errorText: String?
    @State private var confirmationText: String?

    init(
        session: FocusSession,
        calendar: Calendar,
        onDismiss: @escaping () -> Void
    ) {
        self.session = session
        self.calendar = calendar
        self.onDismiss = onDismiss
        _startedAt = State(initialValue: session.startedAt ?? session.completedAt ?? Date())
        _durationMinutes = State(
            initialValue: min(
                max(Int((session.actualDurationSeconds / 60).rounded()), 1),
                DayPlanBlock.minutesPerDay
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            focusSummary

            VStack(alignment: .leading, spacing: 12) {
                DatePicker(
                    "Start",
                    selection: $startedAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)

                DayPlanSlotDurationControl(
                    title: "Duration",
                    minutes: $durationMinutes,
                    range: 1...DayPlanBlock.minutesPerDay,
                    step: 5,
                    presets: [15, 25, 45, 60, 90],
                    tint: .teal
                )

                Label(endText, systemImage: "clock")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let confirmationText {
                Label(confirmationText, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                saveChanges()
            } label: {
                Label("Save Changes", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onChange(of: startedAt) { _, _ in
            clearFeedback()
        }
        .onChange(of: durationMinutes) { _, _ in
            clearFeedback()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "timer")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.teal, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Tag Focus")
                    .font(.headline.weight(.semibold))
                Text("Recorded focus session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private var focusSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(session.focusTagTitle ?? "#Tag", systemImage: "tag.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Adjust when this Focus started and how long it lasted.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if session.accumulatedPausedSeconds > 0 {
                Label(
                    "Saving replaces its paused segments with one continuous interval.",
                    systemImage: "pause.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 10, tint: .teal, tintOpacity: 0.07)
    }

    private var endText: String {
        let endDate = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        if calendar.isDate(startedAt, inSameDayAs: endDate) {
            return "Ends \(endDate.formatted(date: .omitted, time: .shortened))"
        }
        return "Ends \(endDate.formatted(date: .abbreviated, time: .shortened))"
    }

    private func saveChanges() {
        guard
            DayPlanFocusSessionPlannerSync.updateCompletedTagFocusSession(
                session,
                startedAt: startedAt,
                durationMinutes: durationMinutes,
                calendar: calendar,
                context: modelContext
            ) != nil
        else {
            errorText = "This recorded tag Focus could not be updated."
            confirmationText = nil
            return
        }

        do {
            try modelContext.save()
            errorText = nil
            confirmationText = "Focus time updated."
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            errorText = error.localizedDescription
            confirmationText = nil
        }
    }

    private func clearFeedback() {
        errorText = nil
        confirmationText = nil
    }
}
